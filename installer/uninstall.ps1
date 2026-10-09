# VOCALOID6 Editor 비공식 한글 패치 제거
# 자동 업데이터 작업과 패치 파일(en-US의 한글 리소스)을 지운다. 에디터는 영어로 돌아간다.
$ErrorActionPreference = 'Stop'
$TaskName = 'VOCALOID6 KoPatch Updater'
$InstallDir = "$env:ProgramData\VOCALOID6-KoPatch"
$Target = 'C:\Program Files\VOCALOID6\Editor\en-US'
trap {
    Write-Host "오류: $_" -ForegroundColor Red
    Read-Host '엔터를 누르면 닫힙니다'; exit 1
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) {
    Write-Host '관리자 권한으로 다시 실행합니다...'
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    return
}
if (Get-Process VOCALOID6 -ErrorAction SilentlyContinue) { throw 'VOCALOID6 Editor를 종료한 뒤 다시 실행하세요.' }

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
# 패치 표식이 있는 파일만 삭제
Get-ChildItem $Target -Filter *.resources.dll -ErrorAction SilentlyContinue |
    Where-Object { $_.VersionInfo.FileDescription -eq 'VOCALOID6 KoPatch' } |
    Remove-Item -Force
if ((Test-Path $Target) -and -not (Get-ChildItem $Target)) { Remove-Item $Target -Force }
# 실행 중인 스크립트 자신이 이 폴더에 있을 수 있으므로 나머지 정리 후 마지막에 삭제
Set-Location $env:TEMP
Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host '한글 패치를 제거했습니다. 에디터는 영어로 표시됩니다.' -ForegroundColor Green
Read-Host '엔터를 누르면 닫힙니다'
