# NotiMemo

**고정 메모 알림 앱**

NotiMemo는 사용자가 작성한 메모를 알림창에 고정시켜 항상 표시해주는 간단한 유틸리티 앱입니다. 중요한 정보를 놓치지 않도록 도와줍니다.  
안드로이드 기반 기기에서 실행 가능하며, 직관적인 인터페이스와 빠른 접근성을 제공합니다.

---

## 주요 기능

-  **알림 고정 메모**: 작성한 메모를 알림창에 고정하여 항상 표시.
-  **앱 재실행 시 자동 불러오기**: 이전에 작성한 메모를 자동으로 복원.
-  **메모 내역 관리**: 고정했던 메모들의 내역을 하단 시트(Bottom Sheet)로 확인.
-  **메모 내역 내 개별 삭제 및 전체 초기화**: 메모 내역을 개별 혹은 전체 삭제 가능.
-  **라이트 / 다크 모드 지원**: 시스템 설정에 따라 자동 전환.
-  **알림 권한 요청 및 상태 관리**: 권한 미허용 시 안내 메시지 표시.
-  **시작 애니메이션**: 앱 실행 시 Fade + Slide 진입 효과.

---

## 설치 방법

1. [Releases](https://github.com/Mino7406/NotiMemo/releases) 탭에서 최신 APK 다운로드
2. 안드로이드 기기에 APK 설치
3. 앱 실행 후 메모 입력 및 알림 고정 기능 사용

※ 갤럭시 One UI 기준으로 테스트됨.

---

## 스크린샷

![image]("https://github.com/user-attachments/assets/7699e573-c05a-4888-8aae-1906a4b7c474")


---

## 기술 스택

- Flutter / Dart
- flutter_local_notifications — 알림 생성 및 제어
- shared_preferences — 메모 데이터 로컬 저장
- permission_handler — 알림 권한 요청 및 상태 확인
- Flutter MethodChannel — Flutter ↔ 네이티브 Android 통신
- Material 3 UI (라이트 / 다크 테마)

---

## 제작자

[@Mino7406](https://github.com/Mino7406)

---


