export const meta = {
  name: 'notimemo-demo-edl',
  description: 'Analyze NotiMemo demo recordings frame-by-frame and design a verified cut/subtitle edit list',
  phases: [
    { title: 'Analyze', detail: 'one agent per source video, 1s-resolution scene timeline' },
    { title: 'Design', detail: 'edit decision list + subtitles' },
    { title: 'Critique', detail: 'check cut points, subtitles, privacy against frames' },
  ],
}

const FR = 'C:\\Users\\OWNER\\Downloads\\notimemo_demo\\frames'
const VIDEOS = [
  { key: 'A', file: 'Screen_Recording_20261005_183619.mp4', dur: 87.1, res: '1080x2340', sheets: 9 },
  { key: 'C', file: 'Screen_Recording_20261005_184830.mp4', dur: 101.0, res: '720x1560', sheets: 11 },
  { key: 'D', file: 'Screen_Recording_20261005_185126_One UI Home.mp4', dur: 15.1, res: '720x1560', sheets: 2 },
]
const sheetList = v => Array.from({ length: v.sheets }, (_, i) => `${FR}\\${v.key}_${String(i + 1).padStart(2, '0')}.jpg (covers ${i * 10}s–${i * 10 + 9}s)`).join('\n')

const CONTEXT = `Context: 알림메모 (NotiMemo) is a Flutter Android app (repo in the current working directory; PLAN.md / README may help with feature names). Core idea: pin a memo as a persistent notification so you can see it in the notification shade any time. Features include: pinning memos to notifications, editing/clearing/replying from the notification itself, AI 자동 정리 (AI analyzes the memo, suggests category/priority/reservation time, runs via Cloudflare server), 예약 (schedule the pin for a later time, with 여유 시간 lead time), 사진으로 메모 가져오기 (camera/gallery OCR of handwriting), 알림 내역 (history with category/priority filters), 예약 목록, 설정 (theme, vibration, AI toggles, lead time), home-screen widget.
We are editing a demo video for a school engineering fair (공학제) submission. Source screen recordings are vertical phone recordings. Frame sheets: each JPG is a 5x2 grid of frames sampled at 1 fps, each frame labeled with its timestamp in seconds (yellow label top-left). Each cell is 270px wide (proportionally scaled from the source).
Known nuisances: the status bar shows a red screen-recording indicator; the notification shade shows a "녹화를 중지하려면 여기를 누르세요" screen-recorder notification; the settings screen shows the developer's personal email (rlaalsgh7406@gmail.com) in 앱 정보 — must be blurred in the final video.`

const ANALYSIS = {
  type: 'object',
  properties: {
    scenes: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          start: { type: 'number' }, end: { type: 'number' },
          what: { type: 'string', description: 'exactly what happens on screen, incl. text typed, buttons tapped, toasts' },
          feature: { type: 'string' },
          value: { type: 'string', enum: ['highlight', 'useful', 'filler', 'cut'] },
          note: { type: 'string', description: 'transitions, dead time, typing that could be sped up, mistakes, awkward results' },
        },
        required: ['start', 'end', 'what', 'feature', 'value'],
      },
    },
    privacy: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          start: { type: 'number' }, end: { type: 'number' },
          what: { type: 'string' },
          box: { type: 'string', description: 'region as fractions of frame: x,y,w,h (0..1), generous margins; note if it moves due to scrolling and give per-second boxes if so' },
        },
        required: ['start', 'end', 'what', 'box'],
      },
    },
    summary: { type: 'string' },
  },
  required: ['scenes', 'privacy', 'summary'],
}

const EDL = {
  type: 'object',
  properties: {
    segments: {
      type: 'array',
      description: 'in final playback order',
      items: {
        type: 'object',
        properties: {
          src: { type: 'string', enum: ['A', 'C', 'D'] },
          start: { type: 'number', description: 'source seconds, may be fractional' },
          end: { type: 'number' },
          speed: { type: 'number', description: '1.0 normal; 1.5-3 for typing/dead time' },
          purpose: { type: 'string' },
          subtitles: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                from: { type: 'number', description: 'SOURCE seconds within this segment' },
                to: { type: 'number' },
                text: { type: 'string', description: 'Korean, max ~18 chars per line, use \\n for at most 2 lines' },
                pos: { type: 'string', enum: ['top', 'bottom'], description: 'choose the side that does not cover the action (keyboard/sheets at bottom → top)' },
              },
              required: ['from', 'to', 'text', 'pos'],
            },
          },
        },
        required: ['src', 'start', 'end', 'speed', 'purpose', 'subtitles'],
      },
    },
    blurs: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          src: { type: 'string', enum: ['A', 'C', 'D'] },
          start: { type: 'number' }, end: { type: 'number' },
          x: { type: 'number' }, y: { type: 'number' }, w: { type: 'number' }, h: { type: 'number' },
          what: { type: 'string' },
        },
        required: ['src', 'start', 'end', 'x', 'y', 'w', 'h', 'what'],
      },
    },
    cover_status_bar: { type: 'boolean', description: 'whether to paint over the top status bar (recording indicator) for the whole video' },
    status_bar_height: { type: 'number', description: 'fraction of frame height' },
    intro_card: { type: 'string', description: 'text for a 2-3s opening title card' },
    outro_card: { type: 'string' },
    est_total_seconds: { type: 'number' },
    rationale: { type: 'string' },
  },
  required: ['segments', 'blurs', 'cover_status_bar', 'status_bar_height', 'intro_card', 'outro_card', 'est_total_seconds', 'rationale'],
}

phase('Analyze')
const analyses = await parallel(VIDEOS.map(v => () => agent(
  `${CONTEXT}

Your job: build a precise 1-second-resolution scene timeline for source video ${v.key} (${v.file}, ${v.dur}s, ${v.res}). Read EVERY sheet with the Read tool:
${sheetList(v)}

For each scene give exact start/end seconds (use the yellow labels), describe precisely what happens (text typed, buttons tapped, sheets that open, toasts, results), which feature it demonstrates, and rate its value for the demo. Flag dead time, transitions, typing that could be sped up, and anything awkward (e.g. OCR misreads). List every privacy issue with a blur box as fractions of the frame (status bar recorder dot, recorder notification in the shade, personal email). If a box moves because the screen scrolls, give separate time ranges. Be exhaustive and exact — another agent will cut the video based only on your timeline.`,
  { label: `analyze:${v.key}`, phase: 'Analyze', schema: ANALYSIS })))

const byKey = {}
VIDEOS.forEach((v, i) => { byKey[v.key] = analyses[i] })
const analysisText = JSON.stringify(byKey, null, 1)

phase('Design')
const draft = await agent(
  `${CONTEXT}

Scene timelines from three source videos (A = main features 87s 1080x2340, C = history/settings/reservation 101s 720x1560, D = home widget 15s 720x1560; a fourth file was a duplicate of A and is ignored):
${analysisText}

Frame sheets are at ${FR}\\{A,C,D}_NN.jpg (sheet NN covers (NN-1)*10 .. NN*10-1 seconds) — Read them to confirm exact cut points.

Design the edit decision list for a demo video of roughly 2:00–2:45, vertical, priorities: (1) tight cuts — remove dead time, transitions, duplicate demonstrations; speed up typing 1.5–2.5x; (2) Korean burned-in subtitles in a natural MIX of tones — some explanatory ("AI가 메모를 분석해 예약 시각을 제안해요") and some demo-narration ("이번엔 사진으로 메모를 가져와 볼게요"), friendly 해요체, concise. Order the story logically: core concept (pin to notification) → interacting from the notification → AI 자동 정리 + 예약 → 사진 OCR → 알림 내역 / 예약 목록 → 설정 → 홈 위젯. Avoid showing the same feature twice unless the second shows something new. Cut boundaries must land on stable frames, not mid-animation. Subtitles must match what is actually on screen at that moment and must not cover the key UI being demonstrated (use pos top when keyboard or bottom sheets are visible). Every privacy issue in kept ranges must have a blur box (fractions of frame, generous). Decide whether to paint over the status bar for the whole video. Provide intro/outro card text.`,
  { label: 'design:edl', phase: 'Design', schema: EDL })

phase('Critique')
const final = await agent(
  `${CONTEXT}

Here is a draft edit decision list for the demo video:
${JSON.stringify(draft, null, 1)}

Scene timelines it was based on:
${analysisText}

Frame sheets: ${FR}\\{A,C,D}_NN.jpg (sheet NN covers (NN-1)*10 .. NN*10-1 s; A has 9 sheets, C 11, D 2).

Act as a skeptical video editor. Open the frame sheets with Read and verify EVERY segment boundary and EVERY subtitle against the actual frames: does the cut land on a stable frame? does the subtitle text describe what is on screen during its from–to window? does it cover the UI being shown? Are there remaining dead seconds, duplicated demos, or missing important features? Is every frame showing the personal email or the recorder notification covered by a blur box over the right region (check box coordinates against the frames)? Is the speed sensible (typing readable but not slow)? Is the Korean natural and the tone mix good? Then return the CORRECTED full edit decision list (not a diff) — keep what's right, fix what's wrong, and explain changes in rationale.`,
  { label: 'critique:edl', phase: 'Critique', schema: EDL })

return { analyses: byKey, draft, final }
