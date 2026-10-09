using System.Reflection;
using System.Resources;
using System.Runtime.Loader;
using System.Text;
using System.Text.RegularExpressions;

// ResTool: VOCALOID6 한글 패치 번역 도구
//   sync  <VOCALOID6.dll> <ko.tsv>      설치된 에디터의 영어 원문으로 en 열을 갱신 (ko 유지)
//   build <ko.tsv> <out.resources>      ko 열로 .resources 생성 (Yamaha 파일 불필요)
//   check <ko.tsv>                      검증만 수행
//
// ko.tsv 형식: key<TAB>en<TAB>ko  (첫 줄은 헤더, 값 안의 \ \r \n \t 는 이스케이프)

const string ResourcePrefix = "Yamaha.VOCALOID.Properties.Resources";

try
{
    switch (args.ElementAtOrDefault(0))
    {
        case "sync": return Sync(args[1], args[2]);
        case "build": return Build(args[1], args[2]);
        case "check": return Build(args[1], null);
        default:
            Console.Error.WriteLine("usage: ResTool sync <VOCALOID6.dll> <ko.tsv> | build <ko.tsv> <out.resources> | check <ko.tsv>");
            return 2;
    }
}
catch (Exception e)
{
    Console.Error.WriteLine(e.Message);
    return 1;
}

static int Sync(string dllPath, string tsvPath)
{
    var asm = new AssemblyLoadContext("src", isCollectible: true).LoadFromAssemblyPath(Path.GetFullPath(dllPath));
    var name = asm.GetManifestResourceNames().Single(n => n.StartsWith(ResourcePrefix) && n.EndsWith(".resources"));
    var en = ReadStrings(asm.GetManifestResourceStream(name)!);
    var old = File.Exists(tsvPath) ? Tsv.Read(tsvPath) : new();

    int added = 0, changed = 0;
    var rows = new List<Row>();
    foreach (var (key, value) in en.OrderBy(k => k.Key, StringComparer.Ordinal))
    {
        if (!old.TryGetValue(key, out var prev))
        {
            Console.WriteLine($"[새 문자열] {key}: {Tsv.Escape(value)}");
            added++;
            rows.Add(new Row(key, value, ""));
        }
        else
        {
            if (prev.En != value)
            {
                Console.WriteLine($"[원문 변경] {key}: {Tsv.Escape(prev.En)} → {Tsv.Escape(value)}");
                changed++;
            }
            rows.Add(prev with { En = value });
        }
    }
    // 원문에서 사라진 키도 번역은 남겨둔다 (구버전 에디터 호환)
    var removed = old.Values.Where(r => !en.ContainsKey(r.Key)).ToList();
    foreach (var r in removed) Console.WriteLine($"[원문에 없음] {r.Key}");
    rows.AddRange(removed);

    Tsv.Write(tsvPath, rows.OrderBy(r => r.Key, StringComparer.Ordinal));
    Console.WriteLine($"en={en.Count} 새 문자열={added} 원문 변경={changed} 원문에 없음={removed.Count} 미번역={rows.Count(r => r.Ko.Length == 0 && r.En.Trim().Length > 0)}");
    return 0;
}

static int Build(string tsvPath, string? outPath)
{
    var rows = Tsv.Read(tsvPath).Values;
    var problems = 0;
    var writer = outPath is null ? null : new ResourceWriter(outPath);
    var written = 0;
    foreach (var row in rows.OrderBy(r => r.Key, StringComparer.Ordinal))
    {
        if (row.Ko.Length == 0) continue; // 미번역 → 에디터가 영어 원문 사용
        var o = row.En;
        var v = row.Ko;
        // 원문의 줄바꿈 형식을 따른다
        if (o.Contains("\r\n")) v = Regex.Replace(v, "(?<!\r)\n", "\r\n");
        // 원문의 앞뒤 공백은 문자열 이어붙이기에 쓰이므로 그대로 맞춘다
        if (o.Trim().Length > 0) v = o[..(o.Length - o.TrimStart().Length)] + v.Trim() + o[o.TrimEnd().Length..];

        string Ph(string s) => string.Join(",", Regex.Matches(s, @"\{\d+\}").Select(m => m.Value).Order());
        if (Ph(v) != Ph(o)) { Console.WriteLine($"[자리표시자] {row.Key}: 원문 '{Ph(o)}' 번역 '{Ph(v)}'"); problems++; }
        string Ak(string s) => Regex.Match(s, @"\(_[A-Z0-9]\)").Value;
        if (Ak(v) != Ak(o)) { Console.WriteLine($"[단축키] {row.Key}: 원문 '{Ak(o)}' 번역 '{Ak(v)}'"); problems++; }
        if (o.Count(c => c == '|') != v.Count(c => c == '|')) { Console.WriteLine($"[필터 구분자 |] {row.Key}"); problems++; }

        writer?.AddResource(row.Key, v);
        written++;
    }
    writer?.Dispose();
    var untranslated = rows.Where(r => r.Ko.Length == 0 && r.En.Trim().Length > 0).Select(r => r.Key).ToList();
    foreach (var k in untranslated) Console.WriteLine($"[미번역] {k}");
    Console.WriteLine($"전체={rows.Count} 번역={written} 미번역={untranslated.Count} 문제={problems}");
    return problems > 0 ? 1 : 0;
}

static Dictionary<string, string> ReadStrings(Stream s)
{
    var result = new Dictionary<string, string>();
    using var reader = new ResourceReader(s);
    var e = reader.GetEnumerator();
    var names = new List<string>();
    while (e.MoveNext()) names.Add((string)e.Key);
    foreach (var name in names)
    {
        reader.GetResourceData(name, out var type, out var data);
        if (type == "ResourceTypeCode.String")
            result[name] = new BinaryReader(new MemoryStream(data), Encoding.UTF8).ReadString();
    }
    return result;
}

record Row(string Key, string En, string Ko);

static class Tsv
{
    const string Header = "key\ten\tko";

    public static Dictionary<string, Row> Read(string path)
    {
        var rows = new Dictionary<string, Row>();
        var lines = File.ReadAllLines(path, Encoding.UTF8);
        if (lines.Length == 0 || lines[0].TrimStart('\uFEFF') != Header)
            throw new InvalidDataException($"{path}: 헤더가 '{Header.Replace("\t", "<TAB>")}'가 아닙니다");
        for (var i = 1; i < lines.Length; i++)
        {
            if (lines[i].Length == 0) continue;
            var p = lines[i].Split('\t');
            if (p.Length is < 2 or > 3) throw new InvalidDataException($"{path}:{i + 1}: 열 개수가 {p.Length}개입니다");
            if (!rows.TryAdd(p[0], new Row(p[0], Unescape(p[1]), p.Length > 2 ? Unescape(p[2]) : "")))
                throw new InvalidDataException($"{path}:{i + 1}: 중복 키 {p[0]}");
        }
        return rows;
    }

    public static void Write(string path, IEnumerable<Row> rows)
    {
        var sb = new StringBuilder(Header).Append('\n');
        foreach (var r in rows) sb.Append(r.Key).Append('\t').Append(Escape(r.En)).Append('\t').Append(Escape(r.Ko)).Append('\n');
        File.WriteAllText(path, sb.ToString(), new UTF8Encoding(false));
    }

    public static string Escape(string s) =>
        s.Replace("\\", "\\\\").Replace("\r", "\\r").Replace("\n", "\\n").Replace("\t", "\\t");

    public static string Unescape(string s) =>
        Regex.Replace(s, @"\\(.)", m => m.Groups[1].Value switch
        {
            "n" => "\n", "r" => "\r", "t" => "\t", "\\" => "\\",
            var x => "\\" + x,
        });
}
