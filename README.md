## NotiMemo (알림메모)

메모를 **알림창에 고정**해 두고, 앱을 열지 않아도 언제든 확인하고 고치는 안드로이드 메모 앱입니다. Flutter 화면과 네이티브(Kotlin) 알림·알람으로 만들었습니다.

[![Platform](https://img.shields.io/badge/platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white)](https://github.com/Mino7406/NotiMemo/releases)
[![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Release](https://img.shields.io/github/v/release/Mino7406/NotiMemo?style=flat-square)](https://github.com/Mino7406/NotiMemo/releases)
[![language](https://img.shields.io/badge/docs-KR-blue?style=flat-square)](https://github.com/Mino7406/NotiMemo)

_[Releases](https://github.com/Mino7406/NotiMemo/releases) · [개발 기록 (PLAN.md)](PLAN.md)_

## 문제

메모 앱은 열어야 보이고, 알림은 한 번 지나가면 잊힙니다. 일정이나 준비물처럼 "지금 기억해야 할 것"은 열어 보지 않아도 눈에 들어와야 합니다.

## 이 앱이 하는 일

메모를 쓰고 **[알림 고정하기]**를 누르면 그 메모가 알림창에 남습니다. "메모마다 알림 하나, 알림에서 바로 수정하고 지웁니다." 앱을 닫아도 고정한 메모와 예약은 그대로 이어지고, 기기를 다시 켜면 예약은 자동으로 복원되며 고정 알림은 앱을 열 때 복구됩니다.

- **여러 메모 고정**: 메모마다 알림이 하나씩 뜨고, 알림의 `수정` / `지우기` 버튼으로 앱을 열지 않고 고칩니다.
- **예약 알림**: 날짜와 시각(직접 입력 가능)을 정해 두면 그때 알림창에 고정됩니다. 예약 목록에서 확인하고 취소합니다.
- **알림 내역**: 지난 메모를 다시 고정하거나 예약해서 고정합니다. 분류와 우선순위로 걸러 볼 수 있습니다.
- **사진으로 메모 가져오기**: 사진 속 글자를 한국어로 읽어 입력창에 넣습니다. 기기 안에서 처리하므로 인터넷이 없어도 됩니다.
- **AI 자동 정리 (✨)**: 메모의 분류, 우선순위, 한 줄 요약, 일정 시각을 찾아 줍니다. 일정보다 몇 분 앞서 알리는 여유 시간도 설정합니다.
- **홈 화면 위젯**: 위젯에서 바로 메모를 고정하고, 예약 목록과 알림 내역을 봅니다. 기본 4×2, 가로 5칸까지 늘릴 수 있습니다.
- **사용 방법 안내**: 처음 설치하면 실제 화면 위에서 버튼을 하나씩 짚어 주고, ☰ 메뉴의 `사용 방법`으로 다시 볼 수 있습니다.
- **그 밖에**: 라이트 / 다크 테마, 진동 설정, 사라진 고정 알림 자동 복구, 알림 권한 안내, 최신 버전 확인, 복사 / 붙여넣기 등 기본 문구를 기기 언어로 표시합니다.

<!-- 스크린샷은 여기에 추가 -->

## 설치

[Releases](https://github.com/Mino7406/NotiMemo/releases)에서 최신 APK를 받아 안드로이드 기기에 설치합니다.

> **v2.6.0을 쓰던 분은 삭제 후 다시 설치해 주세요.** 배포용 서명 키가 바뀌어서 이전 앱 위에는 덮어쓸 수 없습니다.

갤럭시(One UI, Android 16)에서 테스트했습니다. 알림 고정에는 **알림 권한**이 필요합니다.

## 사용 방법

1. 입력창에 메모를 쓰고 **[알림 고정하기]**를 누릅니다.
2. 글이 있으면 입력창 오른쪽에 버튼이 나타납니다: **✕** 새 메모 지우기, **✨** AI 자동 정리, **🕒** 예약 생성.
3. ☰ 메뉴에서 사진으로 메모 가져오기, 예약 목록, 알림 내역, 설정, 사용 방법을 엽니다.
4. 홈 화면을 길게 눌러 위젯에서 **알림메모**를 추가하면 입력줄을 눌러 바로 고정할 수 있습니다.

## 동작 방식

알림과 알람은 모두 **네이티브(Kotlin)**가 맡고, 화면과 입력은 **Flutter**가 맡습니다.

```
lib/                        Flutter 화면, 저장소, 분류·시간 파서
android/.../notimemo/
├─ NotiMemoService.kt       고정 메모마다 알림 1개 게시, 지우기·수정·재게시 처리
├─ AlarmScheduler.kt        예약 알람 등록·발동, 재부팅 후 복원
├─ NotiMemoWidget.kt        홈 화면 위젯과 목록
├─ QuickInputActivity.kt    위젯에서 뜨는 빠른 입력 창
└─ MainActivity.kt          Flutter ↔ 네이티브 통신(MethodChannel)
worker/                     AI 분류 서버(Cloudflare Workers AI)
```

고정 목록(`pinned_notes`)과 예약 목록(`scheduled_notes`)은 앱과 공유하는 저장소에 **네이티브만 쓰고 Flutter는 읽기만** 합니다. 앱이 꺼져 있어도 알림에서 지우기·수정이 되고 예약이 발동해야 하기 때문입니다.

### 🧩 알아둘 점

- **AI로 보내는 것은 동의한 메모 본문과 설치별 무작위 id뿐입니다.** 안드로이드 고유 번호는 쓰지 않습니다. 동의하지 않거나 서버가 안 될 때는 기기 안의 기본(키워드) 분석으로 대신합니다.
- **하루 20회 제한.** 기기당 하루 20회까지 서버를 부르고, 넘으면 기본 분석으로 정리합니다.
- **예약 시각은 서버가 아니라 앱이 계산합니다.** "내일 오후 3시" 같은 표현을 앱의 시간 파서가 읽습니다.
- **사진은 저장하지 않습니다.** 글자를 읽은 직후 임시 파일을 지웁니다.
- **고정한 알림은 사라지지 않게 지킵니다.** 알림을 밀어서 지워도 다시 게시하고, 강제 종료나 재설치로 사라지면 앱을 켤 때 저장된 목록대로 복구합니다.

## 설정

설정 화면(☰ → 설정)에서 바꿉니다.

- **테마**: 시스템 기본 / 라이트 / 다크
- **알림 진동**: 고정, 예약, 재게시 때 짧게 진동 (기본 켜짐)
- **AI 기능**: 켜면 ✨가 서버 분석을 씁니다. 그 아래에서 **자동 분류** 사용 여부와 **여유 시간**(안 함 / 5분 / 10분 / 30분 / 1시간 / 2시간 / 직접 입력)을 정합니다.
- **앱 정보**: 버전, `업데이트 확인`(최신 릴리스와 비교), 문의

## 제한 사항

- 안드로이드 전용입니다.
- 정확한 알람(`알람 및 리마인더`) 권한이 없으면 예약이 몇 분 늦게 고정될 수 있습니다.
- **VPN을 켜면 AI 서버에 연결되지 않아** 기본 분석으로 넘어갑니다(VPN을 끄거나 이 앱을 VPN 제외 앱에 추가하면 됩니다).
- 위젯 크기와 모양은 제조사 홈 화면에 따라 조금 다르게 보일 수 있습니다.

## 기술 스택

Flutter / Dart, Kotlin, Google ML Kit(한국어 글자 인식, 기기 내 처리), Cloudflare Workers AI(자동 정리 서버), `shared_preferences`, `permission_handler`, `image_picker`, `package_info_plus`, `url_launcher`, `flutter_localizations`.

## 직접 빌드

```
flutter pub get
flutter test
flutter run --release
```

배포용 APK는 서명 키가 필요합니다. 키스토어(`*.jks`)와 `android/key.properties`는 저장소에 올리지 않습니다. 없으면 debug 키로 서명됩니다.

---

made by Mino7406, VVYUNS
