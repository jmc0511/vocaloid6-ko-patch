# (관리자용) 설치된 VOCALOID6 Editor에서 영어 원문을 읽어 translation\ko.tsv의 en 열을 갱신한다.
# 에디터 업데이트 후 실행하면 새로 생기거나 바뀐 문자열이 표시된다. 한국어 번역은 유지된다.
$ErrorActionPreference = 'Stop'
if (Test-Path 'C:\Program Files\dotnet') { $env:PATH = "C:\Program Files\dotnet;$env:PATH" }
$root = $PSScriptRoot
$dll = 'C:\Program Files\VOCALOID6\Editor\VOCALOID6.dll'

dotnet build "$root\tools\ResTool" -c Release -o "$root\tools\bin" --nologo -v q
if ($LASTEXITCODE -ne 0) { throw 'ResTool 빌드 실패' }
Write-Host "에디터 버전: $([Reflection.AssemblyName]::GetAssemblyName($dll).Version)"
dotnet "$root\tools\bin\ResTool.dll" sync $dll "$root\translation\ko.tsv"
