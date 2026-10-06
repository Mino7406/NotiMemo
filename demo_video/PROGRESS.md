# 알림메모 공학제 시연영상 편집 — 진행 상황

마지막 갱신: 2026-10-06 사무실 (5시간 사용량 95%에서 중단)

## 원본 (사무실 PC `C:\Users\OWNER\Downloads`)
| 키 | 파일 | 해상도 | 길이 | 내용 |
|---|---|---|---|---|
| A | Screen_Recording_20261005_183619.mp4 | 1080x2340 | 87s | 고정 알림, 알림에서 수정·지우기, AI 자동 정리·예약, 서랍 메뉴, 사진 OCR |
| (B) | Screen_Recording_20261005_183619 (1).mp4 | 720x1500 | 87s | A와 같은 내용(저해상도), 사용 안 함 |
| C | Screen_Recording_20261005_184830.mp4 | 720x1560 | 101s | 튜토리얼, 알림 내역 필터, 설정, AI 예약, 예약 목록 |
| D | Screen_Recording_20261005_185126_One UI Home.mp4 | 720x1560 | 15s | 홈 화면 위젯으로 메모 고정 |

모두 오디오가 없다. **집 PC에서 할 때:** 위 A·C·D 파일을 집 PC의 `Downloads`에 같은 이름으로 넣는다(폰 갤러리에 원본이 있다). 그리고 `winget install Gyan.FFmpeg`로 ffmpeg를 설치한다. 사무실 PC에는 9.0.2가 설치되어 있다.

## 요구사항
- 컷 편집과 한글 자막을 우선한다. 자막 톤은 설명형과 진행형을 적절히 섞는다.
- 길이는 2:00~2:45 목표, 화면은 세로 그대로.
- 개인정보 처리:
  - 설정 화면의 이메일(영상 C)은 블러한다.
  - 상단 녹화 표시는 상태바 크롭으로 제거한다.
  - 알림창의 "녹화를 중지하려면…" 알림은 블러하거나 컷한다.

## 이 폴더 파일
- `analysis.json`: **완료된 장면 분석 3개**(analyze:A / C / D)
  - 1초 단위 장면 타임라인, 각 장면의 가치(highlight/useful/filler/cut), 잘라낼 구간
  - 블러 박스(프레임 대비 비율)
  - A 분석의 summary에는 추천 러프컷 구간도 들어 있다.
- `workflow_edl.js`: 분석 → 편집안(EDL) 설계 → 검토 워크플로 스크립트. 분석 단계는 끝났고 **설계 단계를 실행하다 멈췄다.**
- `render.js`: EDL JSON으로 최종 영상을 렌더링한다. 사무실에서 테스트를 통과했다.
  - 실행: `cd demo_video` → `node render.js edl.json notimemo_demo_v1.mp4`
  - EDL 형식은 `test_edl.json`을 참고한다. 주요 필드:
    - `segments[src,start,end,speed,subtitles[from,to,text,pos]]`
    - `blurs[src,start,end,x,y,w,h]`: 좌표는 비율, 시간은 원본 초
    - `cover_status_bar`, `status_bar_height`, `intro_card`, `outro_card`
  - 처리 내용:
    - 상태바는 크롭으로 없앤다.
    - 블러는 gblur로 건다.
    - 자막은 맑은 고딕 Bold에 반투명 박스를 깐다. 1.6초보다 짧은 자막은 자동으로 늘린다.
    - 오프닝 3초·엔딩 3.5초 카드에 앱 아이콘을 넣는다.
- 프레임 시트는 저장소에 없다. 필요하면 다시 만든다(1초 간격, 타임스탬프 표시).
  ```
  ffmpeg -i <원본> -vf "fps=1,scale=270:-2,drawtext=fontfile='C\:/Windows/Fonts/malgunbd.ttf':text='%{eif\:t\:d}s':fontsize=30:fontcolor=yellow:box=1:boxcolor=black@0.8:x=6:y=40,tile=5x2" frames/A_%02d.jpg
  ```

## 다음 단계
1. `analysis.json`을 바탕으로 EDL(편집안)을 만들어 `edl.json`으로 저장한다. Claude에게 "PROGRESS.md 보고 이어서"라고 하면 된다.
   - 순서: 고정 알림 → 알림에서 수정·지우기 → AI 자동 정리 + 예약 → 사진 OCR → 알림 내역·예약 목록 → 설정 → 홈 위젯
   - 타이핑은 2~4배속으로 하고 대기 구간은 컷한다.
2. 렌더링하고 결과 프레임을 뽑아 확인한다. 특히 C의 이메일 블러 위치를 본다.
3. 주의할 점:
   - A 79초: OCR이 손글씨 "NotiMemo"를 "Noti Nemo"로 잘못 읽었다. 짧게 쓰거나 자막으로 솔직하게 처리한다.
   - A 60초: 예약 후 키보드가 튀어 올라온다. 59.3초에서 61초로 바로 이어 붙여 건너뛴다.
