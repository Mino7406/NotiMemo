# NotiMemo v3.0 업그레이드 계획 (공학제 출품)

## 인수인계: 이 문서를 처음 읽는 Claude Code 세션에게
이 저장소는 집 PC의 Claude Code 세션이 Phase 1~2를 끝낸 상태다. 이 문서는 그 세션과 사용자가 나눈 대화를 모르는 채로 이어받을 수 있게 쓴 것이다. 아래 순서대로 읽는다.

**시작 전에**
1. `git pull` 로 `master` 최신을 받는다. 작업이 끝난 브랜치는 모두 삭제했고 `master`만 있다.
2. 사용자는 한국어로 대화하고 앱은 한국어 UI다. 답변·커밋 메시지·주석은 한국어로 쓴다(기존 코드 스타일과 같음).
3. 앱은 Flutter(Dart) + 네이티브 Kotlin 혼합이다. 알림·알람은 전부 네이티브, 화면은 Flutter.

**현재 상태 한 줄 요약**: 멀티 메모, 알림 액션(수정/지우기), 예약 알림, 사진 OCR이 완성돼 실기기 확인까지 끝났고, **다음은 Phase 3-7 LLM 자동 분류**다.

### 파일 지도
| 경로 | 역할 |
|---|---|
| `android/.../NotiMemoService.kt` | 포그라운드 서비스. 고정 메모마다 알림 1개 게시, 지우기/재고정/인라인 수정(`RemoteInput`) 처리, 고정 목록 저장 |
| `android/.../AlarmScheduler.kt` | 예약 엔진. `AlarmScheduler`(저장·알람 등록·발동), `AlarmReceiver`, `BootReceiver`가 한 파일에 있음 |
| `android/.../MainActivity.kt` | Flutter ↔ 네이티브 MethodChannel 브리지 |
| `lib/screens/home_screen.dart` | 홈 화면 상태·동작 (고정, 예약, 히스토리, 예약 목록 진입) |
| `lib/screens/scheduled_screen.dart` | 예약 목록 (리스트, 취소, 눌러서 입력창으로 불러오기) |
| `lib/widgets/home_widgets.dart` | 홈 화면 조각 위젯들 (`InputCard`, `PinButton`, `HistoryButton`, `SquareIconButton` 등) |
| `lib/widgets/schedule_sheet.dart` | 예약 시각 선택 하단 시트 (직접 만든 휠 + 빠른 선택 칩) |
| `lib/widgets/history_sheet.dart`, `app_dialogs.dart`, `app_toast.dart` | 히스토리 시트, 다이얼로그, 토스트 |
| `lib/models/memo_entry.dart`, `scheduled_note.dart` | 메모 모델(옛 포맷 마이그레이션 포함), 예약 모델 |
| `lib/storage/memo_storage.dart` | `shared_preferences` 접근 (히스토리, 임시 입력, 고정 id, 예약 목록) |
| `lib/services/notification_service.dart` | MethodChannel 래퍼 |
| `lib/services/ocr_service.dart`, `lib/utils/ocr_text.dart`, `lib/widgets/photo_source_sheet.dart` | 사진 OCR: 사진 선택+ML Kit 인식, 결과 텍스트 정리, 촬영/갤러리 선택 시트 |
| `test/` | 모델·저장소·파싱·OCR 텍스트 정리 단위 테스트 (22개) |

### 데이터 규약 (가장 중요)
- 고정된 메모의 유일한 저장소는 `flutter.pinned_notes`(JSON `[{id,memo,time}]`), 예약은 `flutter.scheduled_notes`(JSON `[{id,memo,at}]`). **둘 다 네이티브가 쓰고 Flutter는 읽기만 한다.** Flutter에서 직접 쓰지 말 것. 앱이 꺼져 있어도 지우기·재고정·예약 발동이 돼야 해서 네이티브가 소유한다.
- Flutter가 읽을 때는 `prefs.reload()`를 먼저 부른다(네이티브가 바꾼 값을 보기 위해). `MemoStorage`의 getter가 이미 그렇게 한다.
- 히스토리(`memo_list`)는 Flutter가 쓰지만, 알림에서 인라인 수정하면 네이티브가 같은 id 항목의 `memo`를 고쳐 쓴다.
- 메모의 `id`는 생성 시각(마이크로초) 기반 문자열. 옛 데이터는 위치 기반 `legacy_<i>`, 옛 단일 메모는 `legacy_current`.
- 저장 포맷은 세 세대(문자열 / `{memo,time}` / 전체 필드)를 모두 읽어야 한다. `MemoEntry.toJson`은 기본값이 아닌 필드만 기록한다(옛 버전 앱 호환).

### MethodChannel (`com.example.notimemo/notification`)
Flutter → 네이티브: `show{id,memo,time}`, `cancel{id?}`(id 없으면 전체 해제), `schedule{id,memo,at}`, `cancelSchedule{id}`, `canScheduleExact`, `requestExactAlarm`.
네이티브 → Flutter: `notificationDismissed`(고정 상태가 바뀜. 이름과 달리 지우기·수정·예약 발동에도 불린다).

### 작업 방식 (사용자와 합의된 흐름)
1. 기능 하나를 시작하기 전에 **설계를 짧게 제시하고 사용자 승인**을 받는다. 승인 전에 코드를 쓰지 않는다.
2. **브랜치를 따로 만들지 않고 `master`에서 바로 작업한다.** 끝나면 사용자가 **실기기에서 직접 테스트**한다.
3. 사용자가 "테스트 다 했어"라고 하면 `master`에 바로 커밋하고 푸시한다(푸시 여부를 따로 묻지 않는다). 이 규칙은 사용자가 정한 것이다.
4. 커밋 메시지는 한국어, `Phase N: ...` 식 요약. 완료한 단계는 이 문서의 "진행 현황" 표를 갱신한다.
5. 빌드 검증은 `flutter analyze`(무결점 유지)와 `flutter test`. 알림·알람 동작은 자동 테스트로 확인할 수 없으니 **실기기 확인 항목을 사용자에게 목록으로 준다.**

### 반드시 피할 것 (실제로 겪은 사고 포함)
- **`flutter install`을 쓰지 말 것.** release APK를 못 찾으면 실패하기 전에 폰의 기존 앱부터 삭제해 저장 데이터가 사라졌다. 설치는 `flutter run -d <기기ID> --no-resident`로 한다. 기기 ID는 `flutter devices`로 확인(집에서는 갤럭시 `R3CXB02YR7V`였고, 다른 PC·기기면 달라진다).
- **`flutter pub get`이 `pubspec.lock`과 `linux/`, `macos/`, `windows/`의 자동 생성 파일을 바꾼다**(Flutter SDK 버전 차이로 패키지 버전이 낮아지기도 함). 의도한 변경이 아니면 커밋하지 말고 `git checkout -- <파일>`로 되돌린다. 브랜치 전환이 막힐 때도 같은 원인이다.
- 폰에 설치한 앱이 디버그 빌드면 애니메이션이 원래 덜 부드럽다. 부드러움 판단은 `flutter run --release -d <기기ID> --no-resident`로 한다(디버그·릴리스가 같은 debug 키로 서명돼 덮어써도 데이터가 유지됨).
- 사용자는 Windows(PowerShell/Git Bash)를 쓴다. 경로에 OneDrive가 끼어 있어 폴더가 동기화 때문에 잠깐 안 보이는 일이 한 번 있었다.

### 다음 작업: Phase 3-7 LLM 자동 분류 (설계는 아직 승인 전)
- 목표: 메모 → JSON `{category, priority, summary, dueTime?}`. `dueTime`이 추출되면 예약과 자동 연동("내일 3시에 ~" 입력이 곧 예약).
- **API 공급자와 키 관리 방식이 아직 미정**이라 사용자에게 먼저 물어야 한다. **키를 APK에 넣지 않는다**는 원칙만 확정(중계 서버 방식 검토). 인터넷이 끊겨도 시연되도록 **키워드 규칙 기반 오프라인 폴백**을 둔다.
- 데이터 모델은 이미 준비돼 있다: `MemoEntry`의 `category`, `priority`, `summary`, `scheduledAt`(사용 시작 전).

### Phase 3-6 OCR에서 알아둘 것
- 입력창 우상단 📷 버튼 → 촬영/갤러리 선택 → ML Kit **한국어** 인식 → 입력창에 이어 붙임(기존 글이 있으면 줄바꿈 후). 고치고 고정/예약하는 건 사용자 몫.
- **한국어 모델은 플러그인이 `compileOnly`로만 선언**해서 `android/app/build.gradle.kts`에 `text-recognition-korean`을 직접 추가했다. 빼면 한글이 깨진다.
- `android/app/proguard-rules.pro`의 `-dontwarn`은 release(R8) 빌드가 중국어·일본어 모델 누락으로 실패하지 않게 하는 규칙이다. release 빌드 성공 확인함.
- 카메라·저장소 권한은 필요 없다(`image_picker`가 시스템 사진 선택기·카메라 앱을 호출). 사진 원본은 저장하지 않고 임시 파일은 인식 직후 지운다.

## 0. 목표
"알림창에 메모 고정" 앱을 **여러 메모 · 예약 · 제로클릭 조작 · AI 자동 정리**까지 되는 앱으로 확장한다.
발표 스토리: `입력(텍스트/사진) → AI가 분류·요약·시간 추출 → 알림에 고정/예약 → 알림창에서 바로 완료 처리`

## 진행 현황 (2026-10-01 기준)
| 단계 | 상태 | 비고 |
|---|---|---|
| Phase 1-1 데이터 모델 확장 + 마이그레이션 | 완료 | `MemoEntry` 필드 확장, 옛 포맷 2종 호환 |
| Phase 1-2 `home_screen.dart` 분리 | 완료 | 1,307줄 → 267줄, `lib/widgets/` 등으로 분리 |
| Phase 1-3 A. 멀티 메모 | 완료 | 실기기 확인 |
| Phase 2-4 B. 알림 액션 버튼 | 완료 (사양 변경) | 아래 "결정 사항" 참고 |
| Phase 2-5 C. 예약 알림 | 완료 (캘린더 뷰 제외) | 예약 목록은 리스트 형식 |
| Phase 3-6 D. 사진 OCR | 완료 | 카메라/갤러리 → 한국어 인식 → 입력창, 실기기 확인 |
| Phase 3-7 E. LLM 자동 분류 | 미착수 | **다음 작업**, 공급자·키 관리 방식 미정 |
| Phase 4-8 F. 위젯 | 미착수 | 디자인·버튼 방식 미정 |

모든 완료 항목은 실기기(갤럭시 SM F956N, Android 16)에서 동작 확인 후 `master`에 병합·푸시함.

### 구현된 구조 (계획 대비 달라진 점)
- **고정 목록의 유일한 저장소**: `flutter.pinned_notes` (JSON `[{id,memo,time}]`). 네이티브 서비스가 쓰고 Flutter는 읽기만 한다. 앱이 꺼져 있어도 지우기·재고정이 동작해야 해서 네이티브가 소유.
- **알림 구조**: 메모마다 알림 1개(ID = 메모 id 해시). 포그라운드 서비스는 앵커 알림 1개만 `startForeground`로 붙들고 나머지는 `notify`. 앵커를 지우면 남은 메모로 앵커 이동. 지우기·재고정·수정은 메모 id 단위.
- **예약 저장소**: `flutter.scheduled_notes` (JSON `[{id,memo,at}]`), 마찬가지로 네이티브가 소유. `AlarmScheduler`(`setExactAndAllowWhileIdle`) → `AlarmReceiver`가 시각에 고정, `BootReceiver`가 재부팅·앱 업데이트 후 복원.
- 옛 단일 메모(`current_memo`)는 첫 실행 때 고정 목록으로 자동 이전.

### 결정 사항 (팀 논의 이후 변경)
- **알림 버튼은 "지우기 / 수정" 2개**로 확정. 계획했던 "완료"와 "5분 뒤 다시"는 뺐다(완료 표시용 `MemoEntry` 필드도 불필요).
- **"수정"은 카카오톡 답장 방식**: 알림창 안에서 바로 입력(`RemoteInput`)하고 전송하면 앱을 열지 않고 알림과 히스토리가 갱신된다. 기존 메모를 입력칸에 미리 채우는 건 안드로이드 제약으로 보장 안 됨(알림 본문에 원문이 보이는 상태에서 새로 입력).
- **예약 시각 선택은 앱 내장 하단 시트**(빠른 선택 칩 + 날짜/오전오후/시/분 휠). 시스템 날짜·시간 팝업은 쓰지 않는다. 별도 패키지 없이 직접 구현.
- 홈 화면 UI는 최소 변경: 입력창·고정 버튼 유지, 고정 버튼 옆에 예약(시계) 버튼, "예약 목록" 버튼 추가.

### 알려진 제약·주의
- **재부팅 직후 이미 지난 예약**: Android 15부터 부팅 직후엔 미디어 재생 유형 포그라운드 서비스를 시작할 수 없어, 고정 대신 일반 알림으로 알린다.
- **정확한 알람 권한(`SCHEDULE_EXACT_ALARM`) 없이 예약**하면 정확도가 낮은 알람으로 대체되고, 백그라운드에서 서비스를 시작하지 못해 일반 알림으로 뜰 수 있다. 첫 예약 때 설정 화면으로 안내한다.
- **`MemoEntry.pinned` 필드는 아직 미사용**: 고정 여부는 `flutter.pinned_notes`의 id로 판단한다. 필드를 계속 둘지는 Phase 3에서 다시 정한다.
- **`flutter_local_notifications`**는 여전히 의존성에만 있고 실제로 쓰이지 않는다(정리 후보).
- 집 PC의 Flutter는 `pub get` 때 `pubspec.lock`의 패키지 버전을 낮추고 플랫폼 자동 생성 파일을 바꿨다. 커밋에서 제외하고 되돌릴 것(자세한 건 위 "반드시 피할 것").
- `flutter install`은 사용하지 말 것(위 "반드시 피할 것" 참고).
- 자동 테스트는 모델·저장소·파싱 로직(14개)만 다룬다. 알림·알람 동작은 실기기 확인이 필요하다.

## 1. 확정 기능 (팀 논의 결과)
| # | 기능 | 비고 |
|---|---|---|
| A | 멀티 메모 (여러 개 동시 고정) | 모든 기능의 기반 |
| B | 알림 액션 버튼 (~~완료 / 5분 뒤 다시~~ → **지우기 / 수정**) | 앱을 열지 않는 "제로 클릭" UX. 수정은 알림 안 인라인 입력 (구현 완료) |
| C | 예약 알림 (설정한 시간에 자동 고정) + 캘린더 형식 예약 목록 | 구현 완료, 예약 목록은 리스트. 캘린더 뷰는 나중에 상세화 |
| D | 사진 촬영 글자 인식 (OCR, 온디바이스) | ML Kit, 무료·오프라인 |
| E | 우선순위/카테고리 자동 분류 (LLM API) | 요약·시간 추출을 한 번의 호출로 같이 처리 |
| F | 위젯 (등록된/예약된 알림 n개 표시) | 디자인·버튼 방식은 추후 구상 |

제외/보류: 음성 입력, 지오펜싱, 커스터마이징 (여유 있을 때만)

## 2. v2.6 시점의 구조 (작업 전 조사 기록 — 현재 코드가 아님)
> 아래는 Phase 1 시작 전에 조사한 내용이다. 지금은 멀티 메모·예약이 구현돼 달라졌으니, 현재 구조는 위 "인수인계"와 "구현된 구조"를 볼 것.

- 알림은 Flutter 패키지가 아니라 **네이티브 Kotlin `NotiMemoService`** (포그라운드 서비스, `NOTIFICATION_ID = 1` 고정)가 만든다. Flutter와는 MethodChannel(`show`/`cancel`)로 통신.
- 메모 저장은 `shared_preferences`: 현재 메모 1개(`saved_memo`) + 히스토리 목록(`memo_list`, `MemoEntry{memo,time}`).
- 지우기 버튼(`ACTION_STOP`), 스와이프 삭제 시 재고정(`ACTION_REPOST`)은 이미 구현됨 → **액션 버튼의 기반이 이미 있음**.
- `flutter_local_notifications`는 의존성에 있지만 예약 수신기(manifest)만 등록돼 있고 실제 알림 생성엔 안 쓰임.
- `home_screen.dart` 1,307줄 단일 파일 → 기능 추가 전에 분리 필요.

## 3. 구현 순서 (권장)
의존 관계와 위험도 기준. 각 단계 끝에 **폰에서 동작 확인 → 커밋**.

### Phase 1. 기반 공사 (필수)
1. **데이터 모델 확장**: `MemoEntry`에 `id`, `pinned`, `category`, `priority`, `summary`, `scheduledAt` 필드 추가. 기존 저장 데이터는 **마이그레이션**(기존 `String`/`{memo,time}` 포맷 호환 유지).
2. **`home_screen.dart` 분리**: 위젯/다이얼로그/바텀시트를 파일로 나눔 (이후 작업 충돌·오류 방지).
3. **A. 멀티 메모**: 서비스가 메모별 알림 ID를 관리. 포그라운드 서비스는 **대표 알림 1개를 앵커**로 두고 나머지는 `NotificationManager.notify`로 게시(그룹화). 메모별 지우기/재고정 동작 유지.

### Phase 2. 핵심 UX
4. **B. 알림 액션 버튼**: 완료(삭제+히스토리 표시) / 5분 뒤 다시(예약) / 수정(앱의 해당 메모 편집 화면 딥링크). 이미 있는 `ACTION_STOP`/`REPOST` 확장.
5. **C. 예약 알림**: `AlarmManager.setExactAndAllowWhileIdle` (정확 알람 권한 `SCHEDULE_EXACT_ALARM` 안내 포함) + 재부팅 시 복원(BootReceiver). 5분 뒤 다시(B)도 같은 엔진을 사용. 예약 목록 화면(캘린더 형식은 v1은 리스트 → 이후 캘린더 뷰).

### Phase 3. AI 기능 (가산점)
6. **D. OCR**: `google_mlkit_text_recognition` + 카메라/갤러리 선택 → 인식 텍스트를 메모 입력창에 채워 편집 후 고정.
7. **E. LLM 자동 분류**: 메모 → JSON `{category, priority, summary, dueTime?}`. 
   - **API 키를 APK에 넣지 않는다.** 무료 서버리스 함수(중계)를 두거나, 최소한 시연용 키는 별도 관리.
   - **오프라인 폴백**: 키워드 규칙 기반 분류(인터넷 끊겨도 시연 가능).
   - `dueTime`이 추출되면 C 예약과 자동 연동 → "내일 3시에 ~" 입력이 곧 예약 알림.

### Phase 4. 위젯
8. **F. 홈 화면 위젯**: 네이티브(Kotlin) `AppWidgetProvider` + 저장 데이터 공유. 표시 항목(현재 고정 n개 / 예약 n개)만 우선 구현, 디자인·버튼은 추후.

## 4. 위험 요소
| 위험 | 대응 |
|---|---|
| 갤럭시 배터리 최적화가 서비스/알람 종료 | 배터리 최적화 제외 안내 화면, 실기기 테스트 필수 |
| Android 13+ 알림 권한, 14+ 정확 알람·포그라운드 서비스 타입 | 권한 요청 흐름 정리, manifest 타입 점검 |
| 멀티 메모로 인한 서비스 재작성 회귀 버그 | Phase 1 완료 후 기존 기능(스와이프 재고정, 지우기) 회귀 확인 |
| LLM 시연 중 네트워크 실패 | 오프라인 폴백 + 시연 영상 백업 |
| 에뮬레이터 느림 | 실기기(갤럭시) USB 디버깅으로 테스트 |

## 5. 사용자(개발자)가 개입할 지점
- Phase 2 이후 각 화면의 **디자인/문구/버튼 배치** 확인
- 실기기 동작 오류 리포트
- 위젯 디자인, 캘린더 뷰 상세 사양
- LLM 서비스 선택(API 공급자)과 키 관리 방식

## 6. 발표·심사 준비 (병행)
- 문제 의식: 설문(예: 반 친구 30명) — "메모 앱 써도 잊어버리는 이유"
- 검증: 사용 전/후 비교(준비물 누락 횟수 등)
- 산출물: 아키텍처 다이어그램, 시연 영상(백업용), README·스크린샷 갱신
- 일정: 공학제 마감일 확인 후 Phase별 기한 확정 (**미정**)
