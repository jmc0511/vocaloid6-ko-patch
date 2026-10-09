# VOCALOID6 Editor 비공식 한글 패치 설치
# 자동 업데이터를 C:\ProgramData\VOCALOID6-KoPatch 에 설치하고 작업 스케줄러에 등록한 뒤 바로 한 번 실행한다.
$ErrorActionPreference = 'Stop'
$TaskName = 'VOCALOID6 KoPatch Updater'
$InstallDir = "$env:ProgramData\VOCALOID6-KoPatch"
trap {
    Write-Host "오류: $_" -ForegroundColor Red
    Read-Host '엔터를 누르면 닫힙니다'; exit 1
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) {
    Write-Host '관리자 권한으로 다시 실행합니다...'
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    return
}
if (-not (Test-Path 'C:\Program Files\VOCALOID6\Editor\VOCALOID6.dll')) {
    throw 'VOCALOID6 Editor가 설치되어 있지 않습니다.'
}

# 1) 업데이터 복사, 폴더 권한 잠금 (SYSTEM이 실행하므로 일반 사용자가 수정할 수 없게)
New-Item -ItemType Directory -Force $InstallDir | Out-Null
Copy-Item "$PSScriptRoot\updater.ps1", "$PSScriptRoot\uninstall.ps1", "$PSScriptRoot\uninstall.bat" $InstallDir -Force
icacls $InstallDir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null

# 2) 작업 스케줄러 등록: 로그온 시, 6시간마다, 에디터 설치·업데이트(MSI) 직후
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$InstallDir\updater.ps1`""
$logon = New-ScheduledTaskTrigger -AtLogOn
$periodic = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Hours 6)
$cls = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
$msi = New-CimInstance -CimClass $cls -ClientOnly
$msi.Enabled = $true
$msi.Delay = 'PT1M'
$msi.Subscription = @"
<QueryList><Query Id="0" Path="Application"><Select Path="Application">*[System[Provider[@Name='MsiInstaller'] and (EventID=1033 or EventID=11707 or EventID=11728)]]</Select></Query></QueryList>
"@
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $logon, $periodic, $msi `
    -Principal $principal -Settings $settings -Description 'VOCALOID6 Editor 비공식 한글 패치를 최신으로 유지합니다.' -Force | Out-Null

# 3) 바로 한 번 실행 (에디터가 켜져 있으면 파일을 바꿀 수 없으므로 종료를 기다린다)
while (Get-Process VOCALOID6 -ErrorAction SilentlyContinue) {
    Write-Host 'VOCALOID6 Editor가 실행 중입니다. 에디터를 종료한 뒤 엔터를 누르세요.' -ForegroundColor Yellow
    Read-Host | Out-Null
}
Write-Host '최신 번역을 내려받는 중...'
& powershell -NoProfile -ExecutionPolicy Bypass -File "$InstallDir\updater.ps1"
if ($LASTEXITCODE -ne 0) { throw "업데이터 실행 실패. 로그: $InstallDir\updater.log" }

Write-Host ''
Write-Host '설치 완료! 에디터를 (다시) 실행하면 한국어로 표시됩니다.' -ForegroundColor Green
Write-Host '에디터가 업데이트되어도 자동으로 다시 적용됩니다.'
Write-Host "제거하려면 제어판 대신 이 파일을 실행하세요: $InstallDir\uninstall.bat"
Read-Host '엔터를 누르면 닫힙니다'
