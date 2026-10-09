# translation\ko.tsv → dist\en-US\*.resources.dll (+ 배포용 zip)
# Yamaha 파일 없이 번역 파일만으로 빌드한다. GitHub Actions에서도 이 스크립트를 쓴다.
#
# 에디터는 Windows 표시 언어가 ja-JP가 아니면 UI를 en-US로 고정하므로,
# en-US 위성 어셈블리에 한국어를 넣으면 본체 수정 없이 한글로 표시된다.
# 위성 어셈블리 버전은 본체보다 낮아도 로드되므로 고정값을 쓴다 (에디터 업데이트와 무관).
param(
    [string]$PatchVersion = 'dev'
)
$ErrorActionPreference = 'Stop'
if (Test-Path 'C:\Program Files\dotnet') { $env:PATH = "C:\Program Files\dotnet;$env:PATH" }
$env:DOTNET_CLI_TELEMETRY_OPTOUT = 1
$root = $PSScriptRoot
$culture = 'en-US'
$assemblyVersion = '6.0.0.0'
$out = "$root\dist\$culture"
Remove-Item "$root\dist" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $out, "$root\obj" | Out-Null

dotnet build "$root\tools\ResTool" -c Release -o "$root\tools\bin" --nologo -v q
if ($LASTEXITCODE -ne 0) { throw 'ResTool 빌드 실패' }

$res = "$root\obj\ko.resources"
dotnet "$root\tools\bin\ResTool.dll" build "$root\translation\ko.tsv" $res
if ($LASTEXITCODE -ne 0) { throw '번역 검증 실패' }

# 본체와 플러그인은 같은 리소스 세트를 쓴다
foreach ($name in 'VOCALOID6', 'VOCALOID6Plugin') {
    dotnet build "$root\tools\Satellite" -c Release --nologo -v q `
        "-p:SatName=$name" "-p:SatCulture=$culture" "-p:SatVersion=$assemblyVersion" `
        "-p:PatchVersion=$PatchVersion" "-p:ResFile=$res" -o "$root\obj\sat_$name"
    if ($LASTEXITCODE -ne 0) { throw "위성 어셈블리 빌드 실패: $name" }
    Copy-Item "$root\obj\sat_$name\$name.resources.dll" $out -Force
}

@{ version = $PatchVersion; built = (Get-Date).ToUniversalTime().ToString('o') } |
    ConvertTo-Json | Set-Content "$root\dist\manifest.json" -Encoding UTF8
Compress-Archive -Path "$root\dist\$culture", "$root\dist\manifest.json" -DestinationPath "$root\dist\VOCALOID6-KoPatch.zip" -Force
Write-Host "완료: $root\dist\VOCALOID6-KoPatch.zip ($PatchVersion)"
