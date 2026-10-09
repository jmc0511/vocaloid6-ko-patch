# VOCALOID6 한글 패치 자동 업데이터
# 작업 스케줄러가 SYSTEM 권한으로 실행한다 (로그온 시, 6시간마다, 에디터 설치·업데이트 직후).
#  1) GitHub 최신 릴리스를 확인해 새 번역이 있으면 내려받는다.
#  2) 에디터 업데이트로 패치 파일이 사라졌거나 바뀌었으면 다시 설치한다.
# 인터넷이 없을 때는 마지막으로 받은 캐시로 복구만 한다.
$ErrorActionPreference = 'Stop'
$Repo = 'jmc0511/vocaloid6-ko-patch'
$Asset = 'VOCALOID6-KoPatch.zip'
$Home_ = Split-Path $PSCommandPath
$Editor = 'C:\Program Files\VOCALOID6\Editor'
$Target = "$Editor\en-US"
$Cache = "$Home_\cache"
$StatePath = "$Home_\state.json"
$LogPath = "$Home_\updater.log"
$Marker = 'VOCALOID6 KoPatch'

function Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Write-Host $line
    Add-Content $LogPath $line -Encoding UTF8
}

# 로그가 너무 커지지 않게 최근 500줄만 유지
if ((Test-Path $LogPath) -and (Get-Item $LogPath).Length -gt 200KB) {
    Get-Content $LogPath -Tail 500 | Set-Content "$LogPath.tmp" -Encoding UTF8
    Move-Item "$LogPath.tmp" $LogPath -Force
}

try {
    if (-not (Test-Path "$Editor\VOCALOID6.dll")) { Log '에디터가 설치되어 있지 않음, 건너뜀'; exit 0 }
    $editorVer = (Get-Item "$Editor\VOCALOID6.dll").VersionInfo.FileVersion
    $state = if (Test-Path $StatePath) { Get-Content $StatePath -Raw | ConvertFrom-Json } else { $null }

    # 1) 새 릴리스 확인
    New-Item -ItemType Directory -Force $Cache | Out-Null
    $zip = "$Cache\$Asset"
    $latest = $null
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $rel = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" `
            -Headers @{ 'User-Agent' = 'VOCALOID6-KoPatch-Updater' } -TimeoutSec 30
        $latest = $rel.tag_name
        $url = ($rel.assets | Where-Object name -eq $Asset).browser_download_url
        if (-not $url) { throw "릴리스 $latest 에 $Asset 이 없음" }
        if (-not (Test-Path $zip) -or -not $state -or $state.patch -ne $latest) {
            Log "새 번역 다운로드: $latest"
            Invoke-WebRequest $url -OutFile "$zip.part" -UseBasicParsing -TimeoutSec 120 `
                -Headers @{ 'User-Agent' = 'VOCALOID6-KoPatch-Updater' }
            Move-Item "$zip.part" $zip -Force
        }
    } catch {
        Log "업데이트 확인 실패 (캐시 사용): $($_.Exception.Message)"
    }
    if (-not (Test-Path $zip)) { Log '설치할 패치 파일이 없음'; exit 1 }

    # 2) 압축 해제 후 패치 파일만 골라 검사
    $stage = "$Cache\stage"
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $zip $stage -Force
    $files = Get-ChildItem "$stage\en-US" -Filter '*.resources.dll' |
        Where-Object { $_.Name -in 'VOCALOID6.resources.dll', 'VOCALOID6Plugin.resources.dll' -and $_.VersionInfo.FileDescription -eq $Marker }
    if ($files.Count -ne 2) { throw '패치 파일이 올바르지 않음' }
    $patchVer = (Get-Content "$stage\manifest.json" -Raw | ConvertFrom-Json).version

    # 3) 이미 같은 파일이 설치돼 있으면 끝
    $same = $true
    foreach ($f in $files) {
        $dst = Join-Path $Target $f.Name
        if (-not (Test-Path $dst) -or (Get-FileHash $dst).Hash -ne (Get-FileHash $f.FullName).Hash) { $same = $false }
    }
    if ($same) {
        if (-not $state -or $state.editor -ne $editorVer -or $state.patch -ne $patchVer) {
            @{ patch = $patchVer; editor = $editorVer; updated = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content $StatePath
        }
        exit 0
    }

    # 4) 설치 (에디터나 DAW가 파일을 쓰는 중이면 다음 실행 때 다시 시도)
    if (Get-Process VOCALOID6 -ErrorAction SilentlyContinue) { Log '에디터 실행 중, 다음에 다시 시도'; exit 0 }
    New-Item -ItemType Directory -Force $Target | Out-Null
    foreach ($f in $files) { Copy-Item $f.FullName $Target -Force }
    @{ patch = $patchVer; editor = $editorVer; updated = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content $StatePath
    Log "설치 완료: 패치 $patchVer / 에디터 $editorVer"
} catch {
    Log "오류: $($_.Exception.Message)"
    exit 1
}
