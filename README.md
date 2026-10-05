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

### 목차

| | 문서 | 내용 |
|:--:|---|---|
| ✨ | [주요 기능](#주요-기능) | 앱에서 할 수 있는 것 |
| 🧰 | [기술 스택](#기술-스택) · [폴더 구조](#폴더-구조) | 쓴 라이브러리와 파일 배치 |
| 🚀 | [설치 및 실행](#설치-및-실행) | APK 설치, 직접 빌드, AI 서버 배포 |
| ⚙️ | [설정](#설정) | 설정 화면 항목과 코드 안의 상수 |
| 🎛️ | [화면과 버튼](#화면과-버튼) | 입력창 버튼과 ☰ 메뉴 정리 |
| 🔍 | [기능 상세](#기능-상세) | 기능별 동작 순서 (눌러서 펼치기) |
| 🧩 | [주요 함수](#주요-함수) | 파일별 핵심 함수 (눌러서 펼치기) |
| 🗂️ | [데이터 저장](#데이터-저장) | 저장 키와 네이티브·Flutter가 나눠 쓰는 방식 |
| 🎨 | [코드 컨벤션](#코드-컨벤션) · [권한](#권한) | 코드 작성 규칙, 안드로이드 권한 |

---

## 주요 기능

**📌 알림 고정**

- 여러 메모 고정: 메모마다 알림이 하나씩 뜹니다. 알림에 `수정`, `지우기` 버튼이 있어서 앱을 열지 않고도 고칠 수 있습니다. 알림을 밀어서 지워도 다시 올라옵니다.
- 알림 복구: 강제 종료나 재설치로 알림이 사라지면, 앱을 켤 때 저장해 둔 목록대로 다시 올립니다.
- 진동: 고정하거나 예약할 때 짧게 진동합니다. 설정에서 끌 수 있습니다.

**⏰ 예약 · 내역**

- 예약 알림: 날짜와 시각을 정해 두면 그때 알림이 고정됩니다. 시각은 휠로 고르거나 직접 입력합니다. 예약 목록에서 확인하고 취소할 수 있습니다.
- 알림 내역: 지난 메모를 다시 고정하거나 예약해서 고정할 수 있습니다. 하나씩 지우거나 전체를 지울 수도 있습니다.
- 필터: 내역과 예약 목록을 분류(학교, 할일, 약속, 쇼핑, 건강, 돈, 기타)나 우선순위로 걸러 볼 수 있습니다.

**✨ 입력 · 자동 정리**

- 사진으로 메모 가져오기: 사진 속 글자를 한국어로 읽어서 입력창에 넣습니다. 기기 안에서 처리하기 때문에 인터넷이 없어도 됩니다.
- AI 자동 정리(✨): 메모의 분류, 우선순위, 한 줄 요약, 일정 시각을 찾아 줍니다. 서버가 안 되거나 동의하지 않았으면 기기 안의 키워드 분석으로 대신합니다. 일정보다 몇 분 앞서 알려 주는 여유 시간도 정할 수 있습니다.
- 홈 화면 위젯: 위젯에서 바로 메모를 고정하고, 예약 목록과 알림 내역을 봅니다. 기본 크기는 4×2이고 가로로 5칸까지 늘어납니다.

**🧩 그 밖에**

- 사용 방법: 처음 설치하면 실제 화면 위에 6단계 안내가 뜹니다. ☰ 메뉴에서 다시 볼 수 있습니다.
- 라이트/다크 테마, 기기 언어로 나오는 복사·붙여넣기 메뉴, 알림 권한 안내, 최신 버전 확인

---

## 기술 스택

- [Flutter](https://flutter.dev/) / Dart: 화면, 저장소, 분류와 시간 파서
- Kotlin: 알림 서비스, 예약 알람, 홈 화면 위젯, 빠른 입력 창
- [google_mlkit_text_recognition](https://pub.dev/packages/google_mlkit_text_recognition) ^0.17.1: 한국어 글자 인식(기기 안에서 처리)
- [image_picker](https://pub.dev/packages/image_picker), [permission_handler](https://pub.dev/packages/permission_handler), [shared_preferences](https://pub.dev/packages/shared_preferences), [package_info_plus](https://pub.dev/packages/package_info_plus), [url_launcher](https://pub.dev/packages/url_launcher), `flutter_localizations`
- [Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai/): 자동 정리 서버(`worker/`)
- 데이터 저장: 따로 DB를 두지 않고 안드로이드 SharedPreferences에 모아 둡니다.

---

## 폴더 구조

```
NotiMemo/
├─ lib/
│  ├─ main.dart                 # 시작점. 테마와 번역을 설정하고 HomeScreen을 띄움
│  ├─ screens/
│  │  ├─ home_screen.dart       # 홈 화면. 고정, 예약, ✨, 사진, 내역, 사용 방법, 권한 안내
│  │  └─ settings_screen.dart   # 설정. 테마, 진동, AI, 앱 정보
│  ├─ models/                   # MemoEntry(메모), ScheduledNote(예약), MemoAnalysis(분석 결과)
│  ├─ services/
│  │  ├─ notification_service.dart  # 네이티브(Kotlin) 호출, 알림 권한
│  │  ├─ ai_classifier.dart     # AI 서버 호출, 실패하면 기본 분석으로 대체
│  │  ├─ ocr_service.dart       # 사진 선택과 글자 인식
│  │  └─ update_service.dart    # GitHub 최신 릴리스와 버전 비교
│  ├─ storage/                  # SharedPreferences 읽기/쓰기
│  ├─ utils/                    # 시간 파서, 키워드 분류, 여유 시간, 필터, 글자 정리
│  ├─ widgets/                  # 입력 카드, 시트, 다이얼로그, 토스트, 메뉴, 사용 방법 안내
│  └─ theme/app_theme.dart      # 색
├─ android/app/src/main/
│  ├─ kotlin/com/example/notimemo/
│  │  ├─ NotiMemoService.kt     # 고정 메모마다 알림 하나를 올리고, 지우기·수정·재게시 처리
│  │  ├─ AlarmScheduler.kt      # 예약 알람 등록과 발동, 재부팅 뒤 복원
│  │  ├─ NotiMemoWidget.kt      # 홈 화면 위젯과 목록
│  │  ├─ QuickInputActivity.kt  # 위젯 입력줄을 누르면 뜨는 작은 입력 창
│  │  ├─ WidgetRows.kt          # 위젯 목록 줄을 JSON에서 만드는 함수
│  │  └─ MainActivity.kt        # Flutter와 네이티브 사이 통신
│  └─ res/                      # 위젯 레이아웃, 색(라이트/다크), 스타일
├─ worker/                      # AI 분류 서버(Cloudflare Workers AI)
│  ├─ src/index.js              # 요청 처리. 크기·JSON 확인, 횟수 제한, AI 호출, 결과 정리
│  └─ src/classify.js           # 분류 기준, 프롬프트, 결과 검증
├─ test/                        # 자동 테스트
├─ assets/                      # Caveat 폰트(OFL), 런처 아이콘 원본, README용 아이콘
└─ LICENSE                      # MIT
```

---

## 설치 및 실행

[Releases](https://github.com/Mino7406/NotiMemo/releases)에서 최신 APK를 받아 설치합니다. 갤럭시(One UI, Android 16)에서 테스트했습니다.

> [!IMPORTANT]
> v2.6.0을 쓰고 계셨다면 삭제하고 새로 설치해 주세요. 서명 키가 바뀌어서 이전 앱 위에는 덮어쓸 수 없습니다.

> [!NOTE]
> 알림을 고정하려면 알림 권한이 필요합니다. 처음 설치하면 사용 방법 안내가 끝난 뒤에 권한 창이 뜹니다. 권한이 꺼져 있으면 `설정` 버튼이 달린 안내가 계속 보입니다.

직접 빌드하려면:

```bash
flutter pub get
flutter test
flutter run --release
```

배포용 APK에는 서명 키가 필요합니다. 키스토어(`*.jks`)와 `android/key.properties`는 `.gitignore`로 저장소에서 빼 두었고, 없으면 debug 키로 서명됩니다.

> [!WARNING]
> debug 키로 서명한 APK는 배포 키로 설치된 앱 위에 덮어쓸 수 없습니다. 폰에 설치할 때는 같은 키로 서명한 빌드를 쓰세요.

### AI 서버 (`worker/`)

앱이 호출하는 서버 코드입니다. 직접 배포하려면:

```bash
cd worker
npm install
npm test          # node --test
npx wrangler deploy
```

배포하고 나온 주소를 [`lib/services/ai_classifier.dart`](lib/services/ai_classifier.dart)의 `defaultEndpoint`에 넣으면 됩니다. `wrangler.toml`의 `MODEL`로 모델을 바꿀 수 있고, 짧은 시간에 몰리는 요청을 막는 `LIMITER`(60초에 6회)도 들어 있습니다.

> [!TIP]
> VPN을 켜면 AI 서버에 연결되지 않아서 기본 분석으로 넘어갑니다. VPN을 끄거나 이 앱을 VPN 제외 앱에 넣어 주세요.

---

## 설정

설정 화면(☰ → 설정)에서 바꾸는 값입니다.

| 항목 | 설명 | 기본값 |
|---|---|---|
| 테마 | 시스템 기본, 라이트, 다크 | 시스템 기본 |
| 알림 진동 | 고정, 예약, 재게시 때 60ms 진동 | 켜짐 |
| AI 기능 켜기 | 켜면 ✨가 서버 분석을 씁니다. 켤 때 메모가 외부 서버로 전송된다는 안내와 동의를 받습니다 | 꺼짐 |
| 자동 분류 시스템 | AI를 켰을 때만 보입니다. 끄면 ✨는 메모 속 예약 시각만 찾고 서버로는 보내지 않습니다 | 켜짐 |
| 여유 시간 | 일정 시각보다 몇 분 앞서 알릴지. 안 함, 5분, 10분, 30분, 1시간, 2시간, 직접 입력(최대 24시간) | 30분 |
| 앱 정보 | 버전, 업데이트 확인, 문의 | |

설정 화면이 아니라 코드에서 바꾸는 상수:

| 상수 | 위치 | 설명 |
|---|---|---|
| `AiClassifier.releaseDailyLimit` | `services/ai_classifier.dart` | 기기당 하루 서버 호출 상한(20). 서버에 요청을 보내면 성공 여부와 상관없이 셉니다 |
| `AiClassifier.timeout` | 같은 파일 | 서버 응답을 기다리는 시간(8초). 넘으면 기본 분석으로 대신합니다 |
| `_inputMinLines` | `widgets/home_widgets.dart` | 입력창 최소 줄 수(6). 글이 길어지면 제한 없이 늘어납니다 |
| `_footerFadeStart` / `_footerFadeEnd` | `screens/home_screen.dart` | 아래 손글씨 문구가 옅어지는 구간 |
| `_scrollFadeHeight` | 같은 파일 | 스크롤할 때 내용이 고정 영역과 만나는 곳에서 옅어지는 높이(28) |

---

## 화면과 버튼

| 위치 | 버튼 | 동작 |
|---|---|---|
| 입력창 | `알림 고정하기` | 메모를 알림창에 고정하고 내역에 저장합니다 |
| 입력창 | `알림 지우기` / `모두 지우기` | 고정된 알림을 내립니다. 여러 개면 전부 내립니다 |
| 입력창 오른쪽(글이 있을 때) | ✕ | 새 메모를 지웁니다. 글이 있으면 확인 창이 뜨고, 공백뿐이면 바로 비웁니다 |
| 입력창 오른쪽 | ✨ | AI 자동 정리. 결과 시트에서 적용하거나 예약합니다 |
| 입력창 오른쪽 | 🕒 | 예약 생성 |
| 상단 | ☰ | 오른쪽에서 밀려 나오는 메뉴 |
| ☰ 메뉴 | AI 자동 정리, 사진으로 메모 가져오기 | 입력창 기능을 메뉴에서도 실행 |
| ☰ 메뉴 | 예약 생성, 예약 목록 | 예약 시트, 예약 목록 시트 |
| ☰ 메뉴 | 알림 내역 | 내역 시트(다시 고정 ↻, 삭제 ✕, 전체삭제) |
| ☰ 메뉴 | 설정, 사용 방법 | 설정 화면, 사용 방법 안내 다시 보기 |
| 홈 화면 위젯 | 입력줄, `예약`/`내역` 탭, 목록 항목 | 빠른 입력 창, 위젯 안에서 목록 바꾸기, 앱에서 해당 목록 열기 |

---

## 기능 상세

> [!TIP]
> 항목 제목을 클릭하면 상세 내용이 펼쳐집니다.

<details>
<summary>📌 <b>알림 고정</b> <sub><code>NotiMemoService.kt</code>, <code>home_screen.dart</code></sub></summary>

1. 메모를 쓰고 `알림 고정하기`를 누르면 알림 권한부터 확인합니다. 없으면 요청하고, 막혀 있으면 안내합니다.
2. Flutter가 MethodChannel `show`로 `{id, memo, time}`을 네이티브에 넘깁니다.
3. `NotiMemoService`가 고정 목록(`pinned_notes`)에 추가하고 메모마다 알림을 하나씩 올립니다. 첫 알림은 포그라운드 서비스(앵커)로, 나머지는 일반 `notify`로 올립니다.
4. 알림의 `수정`은 알림 안에서 바로 입력해서 고정 목록과 앱 내역에 반영하고, `지우기`는 그 알림만 내립니다. 밀어서 지우면 `deleteIntent`로 다시 올립니다.
5. 앵커 알림이 지워지면 다른 알림으로 앵커를 옮기고, 고정 목록이 비면 서비스를 끝냅니다.
6. 앱을 켰을 때 고정 목록은 있는데 알림이 하나도 없으면(`restorePinnedIfMissing`) 저장된 목록대로 다시 올립니다.

</details>

<details>
<summary>⏰ <b>예약 알림</b> <sub><code>AlarmScheduler.kt</code>, <code>schedule_sheet.dart</code></sub></summary>

1. 🕒를 누르면 날짜 휠(약 1년치), 오전/오후, 시(1~12)와 분(0~59) 입력 칸으로 시각을 고릅니다. 지난 시각은 확인할 수 없습니다.
2. 정확한 알람(`알람 및 리마인더`) 권한이 없으면 안내하고 설정 화면을 엽니다. 거절해도 예약은 되지만 몇 분 늦을 수 있습니다.
3. 네이티브 `schedule`이 예약 목록(`scheduled_notes`)에 저장하고 `AlarmManager`에 등록합니다. 권한이 있으면 정확한 알람으로 등록합니다.
4. 시각이 되면 `AlarmReceiver`가 `fire`를 불러서 예약을 목록에서 빼고 메모를 고정합니다. 포그라운드 서비스를 시작할 수 없는 상황(부팅 직후 등)이면 일반 알림으로 알립니다.
5. 재부팅이나 앱 업데이트 뒤에는 `BootReceiver`가 알람을 다시 등록합니다. 이미 지난 예약은 바로 올립니다.
6. 예약 목록에서는 ✕나 옆으로 밀기로 취소합니다. 행을 눌러도 취소되지 않습니다.

</details>

<details>
<summary>🗂️ <b>알림 내역 · 예약 목록</b> <sub><code>history_sheet.dart</code>, <code>scheduled_sheet.dart</code>, <code>memo_list_row.dart</code></sub></summary>

- 두 목록은 같은 행 위젯(`MemoListRow`)을 씁니다. `분류 · 우선순위`, 메모, 시간 순으로 보이고 아이콘은 메모 첫 줄 높이에 맞춥니다.
- 위쪽에 `분류`, `우선순위` 필터 칩이 붙습니다. 항목이 2개 미만이거나 분류된 항목이 없으면 숨깁니다. 필터를 건 상태에서도 삭제는 원래 목록의 위치로 처리합니다(`visibleIndexes`).
- 내역 행의 ↻를 누르면 `취소 / 예약해서 고정 / 바로 고정` 중에서 고릅니다. 예약해서 고정할 때는 분류와 우선순위가 그대로 유지됩니다.
- `전체삭제`는 확인 창을 거칩니다. 필터를 건 상태에서도 보이는 것만이 아니라 전체가 지워집니다.
- 분류가 없는 옛 기록은 앱을 열 때 기본 분석으로 한 번 채웁니다(`backfillClassification`). 설정에서 AI를 켜고 자동 분류를 끈 경우에는 채우지 않습니다.

</details>

<details>
<summary>📷 <b>사진으로 메모 가져오기</b> <sub><code>ocr_service.dart</code>, <code>ocr_text.dart</code></sub></summary>

1. ☰ → `사진으로 메모 가져오기`에서 카메라 촬영이나 갤러리 선택을 고릅니다.
2. ML Kit 한국어 모델로 글자를 읽고, `cleanOcrText`가 줄 끝 공백, 연속된 빈 줄, 앞뒤 빈 줄을 정리합니다.
3. 새 메모가 비어 있으면 바로 채웁니다. 이미 글이 있으면 "기존 메모를 지우고 불러오시겠습니까?" 토스트로 먼저 묻고, 적용하면 사진 글자로 바뀝니다.
4. 채워진 뒤에는 ✨를 가리키는 반투명 말풍선("AI가 자동으로 분석해줘요!")이 12초 동안 깜빡입니다. 누를 수는 없는 안내입니다.
5. 사진 원본은 저장하지 않고, 임시 파일은 글자를 읽은 직후에 지웁니다.

</details>

<details>
<summary>✨ <b>AI 자동 정리</b> <sub><code>ai_classifier.dart</code>, <code>rule_classifier.dart</code>, <code>worker/</code></sub></summary>

1. ✨를 처음 누르면 동의 창이 뜹니다. 메모가 외부 서버로 전송된다는 것과 기기당 하루 20회라는 것을 알려 줍니다. 동의 여부는 저장되고 설정에서 바꿀 수 있습니다.
2. `AiClassifier.analyze`가 동의 여부, 오늘 사용 횟수를 차례로 확인하고 서버를 부릅니다. `X-Device-Id` 헤더에는 설치마다 만든 임의의 id를 넣습니다. 서버에 닿는 시도는 성공 여부와 상관없이 횟수에 셉니다.
3. 서버는 분류(`학교/할일/약속/쇼핑/건강/돈/기타`), 우선순위(`low/normal/high`), 한 줄 요약(30자 이내, 25자 이하의 짧은 메모는 요약 없음)을 돌려줍니다.
4. 어느 단계에서든 실패하면 예외를 던지지 않고 키워드 기반 기본 분석(`classifyByRules`)으로 대신하고, 이유를 사용자에게 보여 줍니다. 동의 안 함, 하루 횟수 소진, 오프라인, 응답 지연, 서버 사용량 소진, 요청 과다, 서버 오류가 있습니다.
5. 결과 시트에는 분류, 우선순위, 요약, 일정 시각과 함께 `AI 분석` 또는 `기본 분석`이 표시됩니다. 적용하면 요약이 있을 때 입력창 메모가 요약으로 바뀌고, `되돌리기` 토스트(6초)로 원문을 되살릴 수 있습니다. 요약을 고쳤다면 덮어쓰지 않습니다.
6. 일정 시각이 있으면 `suggestReminder`가 여유 시간만큼 앞당긴 시각을 예약 시각으로 제안합니다.

</details>

<details>
<summary>🕘 <b>시간 파서</b> <sub><code>due_parser.dart</code>, <code>reminder_time.dart</code></sub></summary>

- 일정 시각은 서버가 아니라 앱 안의 규칙 기반 한국어 파서가 계산합니다. LLM이 요일 표현을 한 주 뒤로 계산하는 일이 있었고, 오프라인에서도 같은 결과가 나와야 해서 이렇게 했습니다.
- 읽는 표현은 `30분 뒤`, `2시간 후`, `1시간 30분 뒤`, `오늘` `내일` `낼` `모레` `글피`, `10월 15일`, `2027년 3월 5일`, 요일(`금요일`, `다음주 월요일`, `담주 수욜`, `이번주말`), `오후 3시 30분`, `저녁 7시`, `3시 반`, `정오`, `자정`, 시간대 단어(`내일 저녁`)입니다.
- 시각 없이 날짜만 있으면 오전 9시로 채우고(`hasTime: false`), 반복 일정(`매주 …`)이나 확실하지 않은 표현은 `null`을 돌려서 예약을 제안하지 않습니다. 틀린 시각으로 알리는 것이 알림이 없는 것보다 낫지 않다고 봤습니다.
- `suggestReminder`는 일정 시각의 N분 전을 알림 시각으로 제안합니다. 이미 지났으면 5분 뒤(일정이 5분 안쪽이면 일정 시각)로 당기고, 시각이 없는 일정은 그대로 둡니다.

</details>

<details>
<summary>🧩 <b>홈 화면 위젯</b> <sub><code>NotiMemoWidget.kt</code>, <code>QuickInputActivity.kt</code>, <code>WidgetRows.kt</code></sub></summary>

1. 위쪽 입력줄을 누르면 앱 전체가 아니라 작은 입력 창(`QuickInputActivity`)이 뜹니다. `알림 고정하기`를 누르면 서비스를 시작하고, 앱 내역(`memo_list`) 맨 앞에 새 항목을 넣고, 진동 설정을 따릅니다. 알림 권한이 없으면 앱을 엽니다.
2. `예약`, `내역` 탭은 위젯 안에서 목록(`NotiMemoWidgetService`)만 바꿉니다. 마지막으로 고른 탭은 따로 저장합니다.
3. 목록 항목을 누르면 앱이 열리고(`open` extra), 그 탭에 맞는 시트(`scheduled`, `history`)가 바로 열립니다.
4. 데이터가 바뀌면(예약 저장, 내역 저장, 알림에서 수정) `NotiMemoWidget.refresh`로 다시 그립니다. Flutter 쪽에서는 `refreshWidget` 채널을 부르고, 안전장치로 30분마다도 갱신합니다.
5. 기본 4×2, 가로 4~5칸, 세로는 자유입니다. 라이트/다크는 리소스 한정자(`values-night`)로 따라갑니다.

</details>

<details>
<summary>🎓 <b>사용 방법 (코치마크)</b> <sub><code>coach_mark.dart</code>, <code>home_screen.dart</code></sub></summary>

- 실제 홈 화면 위에 어두운 막을 씌우고 대상만 둥근 구멍으로 밝혀서 6단계를 안내합니다. 입력창, 알림 고정하기, ✨, 🕒, ☰ 메뉴(메뉴를 실제로 열어서 보여 줌), 알림창에서 수정·지우기 순서입니다.
- 대상은 `Key`로 찾습니다(`input-card`, `pin-button`, `card-analyze`, `card-schedule`, `menu-drawer`). ✨와 🕒는 글이 있어야 보이기 때문에 안내하는 동안 샘플 문구를 잠깐 넣었다가, 끝나면 원래 글로 되돌립니다.
- `이전`, `다음`, `건너뛰기`가 있고 처음 설치할 때만 자동으로 뜹니다(`tutorial_seen`). 이미 쓰던 흔적(내역, 고정, 예약)이 있으면 본 것으로 처리합니다.
- 알림 권한 요청은 이 안내가 끝난 뒤에 합니다.

</details>

<details>
<summary>🔔 <b>권한 안내 · 업데이트 확인</b> <sub><code>notification_service.dart</code>, <code>update_service.dart</code></sub></summary>

- 권한 안내: 알림 권한이 꺼져 있으면 `알림 권한이 꺼져 있어요.` 토스트가 닫을 때까지 남습니다. `설정`을 누르면 권한 요청 창을 다시 띄우고, "다시 묻지 않음"으로 막혀 있으면 앱 설정 화면을 엽니다. 앱을 켤 때와 설정에서 돌아왔을 때 다시 확인합니다.
- 업데이트 확인(설정 → 앱 정보): GitHub 최신 릴리스 태그와 현재 버전을 점(.)으로 나눠서 앞자리부터 비교합니다. 새 버전이면 안내 창이 뜨고(`업데이트`를 누르면 릴리스 페이지), 최신이면 토스트, 실패하면 오류 토스트가 뜹니다. 앱을 켤 때는 새 버전이 있을 때만 조용히 안내합니다.

</details>

---

## 주요 함수

> [!TIP]
> 파일명을 클릭하면 함수 표가 펼쳐집니다.

<details>
<summary>📄 <b><code>services/notification_service.dart</code>: 네이티브 창구</b></summary>

| 함수 | 설명 |
|---|---|
| `show(entry)` / `cancel([id])` | 메모를 고정 / 해제. id가 없으면 전부 해제 |
| `schedule(entry, at)` / `cancelSchedule(id)` | 예약 알람 등록 / 취소 |
| `canScheduleExact()` / `requestExactAlarm()` | 정확한 알람 권한 확인 / 설정 화면 열기 |
| `ensurePermission()` | 알림 권한을 확인하고 필요하면 요청. 쓸 수 있으면 `null`, 아니면 보여 줄 오류 문구 |
| `requestOrOpenSettings()` | 권한 요청 창을 다시 띄움. 막혀 있으면 앱 설정 화면 |
| `restorePinned()` | 고정 목록은 있는데 알림이 없으면 다시 올림 |
| `vibrate()` | 설정이 켜져 있으면 60ms 진동 |
| `refreshWidget()` | 홈 화면 위젯 목록을 다시 그림 |
| `listenForChanges(onChanged, {onOpenTarget})` | 네이티브가 알리는 "고정 상태 변경"과 "위젯에서 열기"를 받음 |
| `launchTarget()` | 위젯에서 눌러 앱이 새로 켜졌을 때 열어야 할 화면. 한 번 읽으면 비워짐 |

</details>

<details>
<summary>📄 <b><code>services/ai_classifier.dart</code>: AI 분석</b></summary>

| 함수 | 설명 |
|---|---|
| `analyze(memo, {now})` | 동의, 하루 횟수를 확인한 뒤 서버를 부릅니다. 실패하면 `classifyByRules`로 대신하고 예외는 던지지 않습니다 |
| `_parse(body, memo, now)` | 서버 응답을 검증. 모르는 분류는 `기타`, 짧은 메모는 요약을 비우고, 일정 시각은 `parseDue`로 계산 |
| `_reasonForError(response)` | 429(`quota_exceeded`와 일반 제한)와 그 밖의 오류를 사용자에게 보여 줄 이유로 바꿈 |

</details>

<details>
<summary>📄 <b><code>utils/</code>: 파서, 분류, 표시</b></summary>

| 함수 | 설명 |
|---|---|
| `parseDue(memo, now)` | 메모에서 일정 시각을 찾아 `ParsedDue(at, hasTime)`로 돌려줌. 불확실하면 `null` |
| `suggestReminder(due, now, {leadMinutes})` | 여유 시간만큼 앞당긴 알림 시각 제안 |
| `leadLabel(lead)` | `30분 전`, `1시간 30분 전` 같은 표시 문구 |
| `classifyByRules(memo, now)` | 키워드로 분류, 우선순위, 요약, 일정을 만드는 기본 분석 |
| `withRuleClassification(entry, now)` / `backfillClassification(list, now)` | 분류가 없는 메모 하나 / 옛 내역 전체를 기본 분석으로 채움 |
| `ClassFilter` / `visibleIndexes(items, filter, classOf)` | 분류·우선순위 필터와, 필터를 통과한 항목의 원래 위치 |
| `cleanOcrText(raw)` | 인식된 글자의 줄 끝 공백과 빈 줄 정리 |
| `formatEntryTime(ms)` / `dateLabel(d, today)` | 목록용 시각 / `10월 2일 (금)` 형태의 날짜 표기 |

</details>

<details>
<summary>📄 <b><code>storage/</code>: 저장소</b></summary>

| 함수 | 설명 |
|---|---|
| `MemoStorage.getList()` / `saveList(list)` | 내역 읽기(옛 형식 3종 호환) / 저장하고 위젯 갱신 |
| `MemoStorage.getPinnedIds()` / `getScheduled()` | 네이티브가 쓴 고정·예약 목록을 읽음(읽기 전에 `reload`) |
| `MemoStorage.getCurrent()` / `setCurrent(memo)` | 입력창에 쓰던 글 임시 저장 |
| `AiStorage.usageToday(now)` / `addUsage(now)` | 오늘 서버 호출 횟수 조회 / 증가. 날짜가 바뀌면 0부터 |
| `AiStorage.getDeviceId()` | 설치마다 만든 임의의 24자 id(안드로이드 고유 번호가 아님) |
| `AiStorage.classificationEnabled()` | 저장할 때 분류를 자동으로 채워도 되는지. AI를 쓰지 않으면 항상 허용 |

</details>

<details>
<summary>📄 <b>네이티브(Kotlin)</b></summary>

| 클래스 / 함수 | 설명 |
|---|---|
| `NotiMemoService.onStartCommand` | 명령(`STOP`, `STOP_ALL`, `EDIT`, `REPOST`, 새 고정)을 처리 |
| `NotiMemoService.post` / `buildNotification` | 알림 게시(앵커 / 일반)와 모양(제목, 굵은 메모, `수정`·`지우기` 버튼) |
| `AlarmScheduler.schedule` / `cancel` / `fire` / `restoreAll` | 예약 등록, 취소, 발동, 재부팅 뒤 복원 |
| `NotiMemoWidget.refresh(ctx)` | 모든 위젯과 목록을 다시 그림. 위젯이 없으면 아무것도 안 함 |
| `QuickInputActivity.pin` | 권한 확인, 서비스 시작, 내역 추가, 위젯 갱신 |
| `WidgetRows.scheduled` / `history` | 위젯 목록 줄을 JSON에서 만듦. JSON이 깨져 있으면 빈 목록 |
| `MainActivity` 채널 메서드 | `show` `cancel` `schedule` `cancelSchedule` `canScheduleExact` `requestExactAlarm` `vibrate` `restorePinned` `refreshWidget` `getLaunchTarget` |

</details>

---

## AI 서버 (`worker/`)

- `POST /classify`: 본문 `{ "memo": "..." }`(4096바이트 이하, 메모는 500자 이하)를 받아 `{ category, priority, summary }`를 돌려줍니다.
- `GET /health`: 상태 확인
- 오류는 `{ "error": 코드 }` 모양입니다. `body_too_large`, `bad_json`, `bad_request`, `empty_memo`, `memo_too_long`, `rate_limited`(분당 6회), `quota_exceeded`(Workers AI 하루 무료 한도 소진), `ai_failed`, `bad_model_output`, `not_found`, `method_not_allowed`, `internal_error`가 있고, 앱은 이 코드를 보고 기본 분석으로 넘어가는 이유 문구를 고릅니다.
- 메모 내용은 로그에 남기지 않습니다. 앱이 보내는 것은 동의한 메모 본문과 설치마다 만든 임의의 id뿐입니다.
- 분류 목록(`CATEGORIES`)은 앱의 `memoCategories`와 같아야 합니다. 한쪽을 바꾸면 다른 쪽도 같이 바꿔 주세요.

---

## 데이터 저장

데이터는 모두 안드로이드 SharedPreferences 한 곳에 있습니다. Flutter에서는 `shared_preferences`로, 네이티브에서는 `FlutterSharedPreferences` 파일의 `flutter.` 접두 키로 읽고 씁니다.

| 키 | 내용 | 쓰는 쪽 |
|---|---|---|
| `pinned_notes` | 고정 중인 메모 `[{id, memo, time}]` | 네이티브만 씀. Flutter는 읽기만 |
| `scheduled_notes` | 예약 목록 `[{id, memo, at}]` | 네이티브만 씀. Flutter는 읽기만 |
| `memo_list` | 알림 내역(메모, 분류, 우선순위, 요약, 예약 시각). 알림에서 고친 내용과 위젯 빠른 입력은 네이티브가 같은 항목에 반영 | Flutter, 일부는 네이티브 |
| `saved_memo` | 입력창에 쓰던 글 임시 저장 | Flutter |
| `ai_consent`, `ai_device_id`, `ai_usage_date`, `ai_usage_count`, `ai_lead_minutes`, `ai_auto_classify` | AI 동의, 설치 id, 오늘 사용 횟수, 여유 시간, 자동 분류 | Flutter |
| `theme_mode`, `vibration_on`, `tutorial_seen` | 테마, 진동, 사용 방법을 봤는지 | Flutter |

- 앱이 꺼져 있어도 알림에서 지우기·수정이 되고 예약이 발동해야 해서, 고정과 예약 목록은 네이티브가 갖고 있습니다. Flutter는 읽기 전에 `reload()`로 네이티브가 바꾼 값을 가져옵니다.
- 메모 id는 생성 시각(마이크로초)을 문자열로 만든 값입니다. 옛 형식(글자만 저장하던 것, `{memo, time}`)은 읽을 때 변환하고, 새 필드는 기본값이 아닐 때만 기록해서 옛 버전 앱이 읽어도 깨지지 않게 했습니다.

---

## 코드 컨벤션

- 주석과 커밋 메시지는 한국어로 짧게 씁니다.
- `dart format`은 파일을 지정해서만 돌립니다. 폴더 전체에 돌리면 건드리지 않은 파일의 줄바꿈까지 바뀝니다.
- 파일은 CRLF(윈도우)입니다. 문자열을 코드로 치환할 때는 줄바꿈을 `\n`으로 통일해서 비교하고, 한글 문자열 안의 `\n`이 실제 줄바꿈으로 들어가지 않게 조심합니다.
- 멀티라인 `TextField`가 들어 있는 화면에는 `IntrinsicHeight`나 `SliverFillRemaining(hasScrollBody: false)` 안의 `Column`을 쓰지 않습니다. 높이를 잘못 재서 아래쪽이 잘립니다.
- 프레임을 그리는 중(persistent frame callback)에 `setState`를 하면 다음 프레임이 예약되지 않으므로 `addPostFrameCallback`을 씁니다.
- 기능을 바꿀 때 `flutter test`도 같이 고칩니다. 알림, 알람, 위젯 같은 네이티브 동작은 자동 테스트가 어려워서 실기기로 확인합니다.

---

## 권한

| 권한 | 용도 |
|---|---|
| `POST_NOTIFICATIONS` | 알림 게시(안드로이드 13 이상) |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | 고정 알림을 서비스로 유지해서 시스템이 정리하지 못하게 함 |
| `SCHEDULE_EXACT_ALARM` | 예약 시각에 맞춰 고정. 없으면 몇 분 늦을 수 있음 |
| `RECEIVE_BOOT_COMPLETED` | 재부팅이나 앱 업데이트 뒤 예약 알람 복원 |
| `VIBRATE` | 고정, 예약 때 진동 |
| `INTERNET` | AI 자동 정리, 업데이트 확인 |

- 사진은 시스템 카메라/갤러리 선택 화면으로 가져오기 때문에 카메라 권한은 따로 요청하지 않습니다.
- AI 서버로 보내는 것은 동의한 사용자의 메모 본문과 설치마다 만든 임의의 id뿐입니다. 동의하지 않았거나 "자동 분류"를 끄면 서버로 보내지 않습니다.

---

## 라이선스

[MIT](LICENSE)입니다. 앱에 들어 있는 Caveat 폰트는 [SIL Open Font License](assets/OFL-Caveat.txt)를 따릅니다.

---

made by Mino7406, VVYUNS
