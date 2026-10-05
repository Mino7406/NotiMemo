<div align="center">

<h1>
  <a href="https://github.com/Mino7406/NotiMemo/releases"><img src="assets/readme_icon.png" width="100" alt="NotiMemo 앱 아이콘"></a><br>
  알림메모 (NotiMemo)
</h1>

메모를 알림창에 고정해 두고, 앱을 열지 않아도 확인하고 고치는 안드로이드 메모 앱입니다. 예약 알림, 알림 내역, 사진 글자 인식, AI 자동 정리, 홈 화면 위젯을 제공합니다. 화면은 [Flutter](https://flutter.dev/), 알림·알람·위젯은 [네이티브(Kotlin)](https://kotlinlang.org/)로 작성했습니다.

[![Android](https://img.shields.io/badge/Android-3DDC84?style=flat-square&logo=android&logoColor=white)](https://developer.android.com/)
[![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Kotlin](https://img.shields.io/badge/Kotlin-native-7F52FF?style=flat-square&logo=kotlin&logoColor=white)](https://kotlinlang.org/)
[![AI server](https://img.shields.io/badge/AI-Cloudflare%20Workers-F38020?style=flat-square&logo=cloudflare&logoColor=white)](https://developers.cloudflare.com/workers-ai/)
[![License: MIT](https://img.shields.io/badge/license-MIT-4c1?style=flat-square)](LICENSE)
![language](https://img.shields.io/badge/docs-한국어-blue?style=flat-square)

</div>

## 기능

- 메모를 쓰고 고정 버튼을 누르면 알림창에 남습니다. 여러 개를 고정할 수 있고, 알림에서 바로 수정하거나 지울 수 있습니다.
- 날짜와 시각을 정해 예약해 두면 그 시각에 알림이 고정됩니다.
- 지난 메모는 알림 내역에 남습니다. 거기서 다시 고정하거나 예약할 수 있고, 분류와 우선순위로 걸러 볼 수 있습니다.
- 사진 속 글자를 읽어서 메모로 옮길 수 있습니다. 글자 인식은 기기 안에서 돌아가서 인터넷이 없어도 됩니다.
- ✨ 버튼을 누르면 메모의 분류, 우선순위, 한 줄 요약, 일정 시각을 찾아 줍니다. AI 서버를 쓰고, 서버가 안 되면 키워드 기반의 단순 분석으로 대신합니다.
- 홈 화면 위젯(메모 바로 고정, 예약 목록, 알림 내역), 처음 설치할 때 뜨는 사용 방법 안내, 라이트/다크 테마, 진동 설정이 있습니다.

## 설치

[Releases](https://github.com/Mino7406/NotiMemo/releases)에서 최신 APK를 받아 설치합니다. 갤럭시(One UI, Android 16)에서만 테스트했습니다.

> v2.6.0을 쓰고 계셨다면 삭제하고 새로 설치해야 합니다. 서명 키를 새로 만들어서 이전 앱 위에는 덮어쓸 수 없습니다. 삭제하면 저장된 메모와 예약이 같이 사라집니다.

알림을 고정하려면 알림 권한이 필요합니다. 예약을 정확한 시각에 맞추려면 `알람 및 리마인더` 권한도 켜 두는 게 좋고, 없으면 몇 분 늦게 고정될 수 있습니다. 그 밖에 인터넷(AI 정리, 업데이트 확인), 진동, 재부팅 후 예약 복원 권한을 씁니다. 사진은 시스템 카메라/갤러리 화면을 거쳐서 가져오기 때문에 카메라 권한은 따로 요청하지 않습니다.

## 사용법

1. 입력창에 메모를 쓰고 `알림 고정하기`를 누릅니다.
2. 글이 있으면 입력창 오른쪽에 버튼이 생깁니다. ✕는 새 메모 지우기, ✨는 AI 정리, 🕒는 예약입니다.
3. 오른쪽 위 ☰ 메뉴에서 사진으로 메모 가져오기, 예약 목록, 알림 내역, 설정, 사용 방법을 열 수 있습니다.
4. 홈 화면을 길게 눌러 위젯에서 알림메모를 추가하면, 위젯의 입력줄에서 바로 메모를 고정할 수 있습니다.

설정에서는 테마, 진동, AI 사용 여부와 여유 시간(일정보다 몇 분 앞서 알릴지)을 바꿀 수 있습니다. AI 기능은 처음 켤 때 메모가 외부 서버로 전송된다는 안내와 함께 동의를 받습니다.

## 만들면서 신경 쓴 것

- **알림이 사라지지 않게.** 고정한 알림을 밀어서 지워도 다시 게시합니다. 강제 종료나 재설치로 사라졌다면 앱을 켤 때 저장된 목록으로 복구합니다. 다만 재부팅 직후에는 앱을 한 번 열어야 고정 알림이 돌아옵니다(예약은 재부팅 후 자동으로 복원됩니다).
- **고정·예약 목록은 네이티브가 저장합니다.** 앱이 꺼져 있어도 알림에서 지우기와 수정이 되고 예약이 발동해야 해서, Kotlin 쪽이 저장소를 직접 쓰고 Flutter는 읽기만 합니다.
- **일정 시각은 AI가 아니라 직접 만든 파서가 계산합니다.** LLM이 "금요일" 같은 요일 표현을 한 주 뒤로 계산하는 일이 잦았고, 오프라인에서도 같은 결과가 나와야 했습니다. 표현이 애매하면 예약을 제안하지 않고 넘어갑니다.
- **AI 서버로 보내는 건 최소한으로.** 동의한 메모의 본문과 설치마다 만든 임의의 id만 보냅니다. 기기당 하루 20회까지만 부르고, 넘거나 서버가 안 되면 기기 안의 분석으로 대신합니다.

## 폴더 구조

```
lib/                          Flutter 화면, 저장소, 분류·시간 파서
  screens/                    홈 화면, 설정 화면
  services/                   네이티브 호출, AI 호출, 사진 글자 인식, 업데이트 확인
  utils/                      시간 파서, 키워드 분류, 여유 시간 계산 등
  widgets/                    입력 카드, 시트, 다이얼로그, 사용 방법 안내
android/app/src/main/
  kotlin/com/example/notimemo/
    NotiMemoService.kt        고정 메모마다 알림 하나를 게시
    AlarmScheduler.kt         예약 알람 등록, 발동, 재부팅 후 복원
    NotiMemoWidget.kt         홈 화면 위젯
    QuickInputActivity.kt     위젯에서 뜨는 빠른 입력 창
    MainActivity.kt           Flutter와 네이티브 사이 통신
worker/                       AI 분류 서버(Cloudflare Workers AI)
test/                         자동 테스트
assets/                       Caveat 폰트(OFL), 아이콘 원본
```

데이터는 별도 DB 없이 안드로이드 SharedPreferences에 저장합니다.

## AI 서버

`worker/`가 앱이 호출하는 서버 코드입니다. 메모를 받아 분류, 우선순위, 요약을 돌려줍니다. 직접 배포하려면 다음과 같이 합니다.

```
cd worker
npm install
npx wrangler deploy
```

배포 후 나온 주소를 `lib/services/ai_classifier.dart`의 `defaultEndpoint`에 넣습니다. 분당 6회로 요청을 제한하고, 메모 내용은 로그에 남기지 않습니다. VPN을 켜면 이 서버에 연결되지 않아서 기본 분석으로 넘어갑니다.

## 직접 빌드

```
flutter pub get
flutter test
flutter run --release
```

배포용 APK는 서명 키(`*.jks`)와 `android/key.properties`가 있어야 합니다. 둘 다 저장소에는 올리지 않았고, 없으면 debug 키로 서명됩니다. debug 키로 서명한 APK는 배포 키로 설치된 앱 위에 덮어쓸 수 없습니다.

## 라이선스

[MIT](LICENSE)입니다. 앱에 들어 있는 Caveat 폰트는 [SIL Open Font License](assets/OFL-Caveat.txt)를 따릅니다.

made by Mino7406, VVYUNS
