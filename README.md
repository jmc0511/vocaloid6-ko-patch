# VOCALOID6 Editor 비공식 한글 패치

VOCALOID6 Editor의 메뉴, 대화 상자, 툴팁, 메시지를 한국어로 표시해 주는 **비공식** 팬 패치입니다.
Yamaha와는 관계가 없습니다.

- 에디터 본체 파일은 수정하지 않고 한국어 리소스 파일만 추가합니다.
- 한 번 설치하면 에디터가 업데이트되어도 자동으로 다시 적용되고, 번역이 개선되면 자동으로 받아옵니다.
- 언제든 깨끗하게 제거할 수 있습니다.

## 설치

1. [Releases](../../releases/latest)에서 `VOCALOID6-KoPatch-Installer.zip`을 내려받아 압축을 풉니다.
2. `install.bat`을 더블클릭합니다. 관리자 권한 확인 창이 뜨면 **예**를 누릅니다.
3. VOCALOID6 Editor를 (다시) 실행하면 한국어로 표시됩니다.

> Windows 표시 언어가 **일본어**이면 에디터가 일본어 모드로 동작해서 패치가 적용되지 않습니다.
> 한국어, 영어 등 다른 언어의 Windows에서 사용하세요.

### 자동 업데이트는 어떻게 동작하나요?

설치하면 작업 스케줄러에 `VOCALOID6 KoPatch Updater` 작업이 등록되고, 다음 시점에 실행됩니다.

- Windows에 로그인할 때
- 6시간마다
- VOCALOID6 Editor를 설치하거나 업데이트한 직후

실행되면 GitHub에서 최신 번역을 확인하고, 필요하면 내려받아 다시 적용합니다.
에디터가 실행 중이면 건너뛰었다가 다음 실행 때 적용합니다.
기록은 `C:\ProgramData\VOCALOID6-KoPatch\updater.log`에 남습니다.

## 제거

`C:\ProgramData\VOCALOID6-KoPatch\uninstall.bat`을 실행하면 자동 업데이트 작업과 패치 파일이 삭제되고, 에디터는 영어로 돌아갑니다.

## 알려진 제한

- 오디오 이펙트 창(리버브, EQ 등)은 별도의 네이티브 플러그인이라 번역되지 않습니다.
- 새 에디터 버전에 추가된 문자열은 번역이 반영될 때까지 영어로 표시됩니다.
- VST/AU 플러그인판(VOCALOID6Plugin)도 같은 방식으로 번역되지만, DAW마다 동작은 확인 중입니다.

## 번역에 참여하기

번역은 [`translation/ko.tsv`](translation/ko.tsv) 하나에 모두 들어 있습니다. 탭으로 구분된 `key`, `en`(영어 원문), `ko`(한국어) 세 열입니다.

- 줄바꿈은 `\n`으로 씁니다.
- `{0}` 같은 자리표시자와 `(_F)` 같은 메뉴 단축키 표시는 원문과 똑같이 유지해야 합니다.
- `ko`를 비워 두면 그 항목은 영어로 표시됩니다.

수정 사항은 Issue나 Pull Request로 보내 주세요. main에 반영되면 GitHub Actions가 자동으로 빌드하고 릴리스하며, 설치된 PC에는 자동으로 전달됩니다.

### 관리자용: 에디터가 업데이트되었을 때

```powershell
./sync.ps1    # 설치된 에디터에서 영어 원문을 읽어 새 문자열과 바뀐 문자열을 표시
# ko.tsv에서 비어 있는 ko 열을 번역
./build.ps1   # 로컬 검증용 빌드 (.NET 8 SDK 필요)
git commit -am "번역: 6.x.x 새 문자열" && git push   # → 자동 릴리스
```

## 동작 원리

VOCALOID6 Editor(.NET 8 / WPF)는 Windows 표시 언어가 일본어가 아니면 UI 언어를 `en-US`로 정합니다.
이 패치는 `C:\Program Files\VOCALOID6\Editor\en-US\` 폴더에 한국어 문자열이 담긴 위성 리소스 어셈블리를 넣습니다.
.NET은 영어 기본값보다 이 파일을 먼저 읽기 때문에, 본체를 고치지 않고도 한국어로 표시됩니다.

## 라이선스

도구와 스크립트는 MIT 라이선스입니다. `translation/ko.tsv`의 영어 원문(`en` 열)은 Yamaha Corporation의 저작물이며, 번역 작업을 위한 참고용으로만 포함되어 있습니다.
VOCALOID는 Yamaha Corporation의 등록 상표입니다.
