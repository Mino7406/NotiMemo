// Usage: node render.js edl.json [outName]
// Renders the NotiMemo demo video from an edit decision list (EDL) with ffmpeg.
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const W = 720, H = 1560;
const DL = path.join(process.env.USERPROFILE, 'Downloads');
const SRC = {
  A: path.join(DL, 'Screen_Recording_20261005_183619 (1).mp4'), // 1080x2340 (this PC); the unnumbered file is the 720x1500 duplicate
  C: path.join(DL, 'Screen_Recording_20261005_184830.mp4'),
  D: path.join(DL, 'Screen_Recording_20261005_185126_One UI Home.mp4'),
};
const ICON = path.join(__dirname, '..', 'assets', 'readme_icon.png').replace(/\\/g, '/');
const FONT = 'C\\:/Windows/Fonts/malgunbd.ttf';
const FONT_R = 'C\\:/Windows/Fonts/malgun.ttf';
const BG = '0x0E0E16';
const MIN_SUB = 1.6; // min on-screen seconds for a subtitle after speed-up

const edl = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const outName = process.argv[3] || 'notimemo_demo.mp4';
const work = path.join(__dirname, 'build');
fs.rmSync(work, { recursive: true, force: true });
fs.mkdirSync(work, { recursive: true });

const even = n => Math.round(n / 2) * 2;
const barH = edl.cover_status_bar ? even(H * edl.status_bar_height) : 0;
const OH = H - barH;
const f3 = n => Number(n).toFixed(3);

function ff(args) {
  const r = spawnSync('ffmpeg', ['-v', 'error', '-y', ...args], { stdio: 'inherit', cwd: work });
  if (r.status !== 0) throw new Error('ffmpeg failed: ' + args.join(' '));
}
function textFile(name, text) {
  fs.writeFileSync(path.join(work, name), text.replace(/\\n/g, '\n'), 'utf8');
  return name;
}
function drawtext(file, { size, y, font = FONT, enable, box = true }) {
  let s = `drawtext=fontfile='${font}':textfile='${file}':fontsize=${size}:fontcolor=white:text_align=C:line_spacing=10:x=(w-text_w)/2:y=${y}`;
  if (box) s += ':box=1:boxcolor=black@0.62:boxborderw=20';
  if (enable) s += `:enable='${enable}'`;
  return s;
}

const parts = [];
const warnings = [];

function card(name, text, dur) {
  const lines = text.replace(/\\n/g, '\n');
  const tf = textFile(`${name}.txt`, lines);
  const iconY = Math.round(OH * 0.30);
  const fc = [
    `[1:v]scale=200:200[ic]`,
    `[0:v][ic]overlay=(W-w)/2:${iconY}[b]`,
    `[b]${drawtext(tf, { size: 40, y: iconY + 260, box: false })},` +
      `fade=t=in:st=0:d=0.4,fade=t=out:st=${f3(dur - 0.4)}:d=0.4,format=yuv420p[v]`,
  ].join(';');
  const out = `${name}.mp4`;
  ff(['-f', 'lavfi', '-i', `color=c=${BG}:s=${W}x${OH}:d=${dur}:r=30`, '-i', ICON,
    '-filter_complex', fc, '-map', '[v]', '-c:v', 'libx264', '-crf', '20', '-preset', 'slow', '-r', '30', '-video_track_timescale', '15360', out]);
  parts.push(out);
}

card('intro', edl.intro_card, 3);

edl.segments.forEach((seg, i) => {
  const n = i + 1;
  const dur = seg.end - seg.start;
  const chain = [];
  let cur = '[0:v]';
  let k = 0;
  const lbl = () => `[s${n}_${k++}]`;
  let next = lbl();
  // Screen recordings are VFR: static screens have sparse frames, so cuts drift. Lock to 30fps from t=0 and trim to the exact length.
  chain.push(`${cur}fps=30:start_time=0,trim=duration=${f3(dur)},setpts=PTS-STARTPTS,scale=${W}:${H},setsar=1${next}`);
  cur = next;

  // privacy blurs (times relative to segment start, before speed change)
  for (const b of edl.blurs.filter(b => b.src === seg.src && b.end > seg.start && b.start < seg.end)) {
    const bx = even(b.x * W), by = even(b.y * H);
    const bw = even(Math.min(b.w * W, W - bx)), bh = even(Math.min(b.h * H, H - by));
    const a = Math.max(0, b.start - seg.start), z = Math.min(dur, b.end - seg.start);
    const keep = lbl(), raw = lbl(), blurred = lbl(); next = lbl();
    chain.push(`${cur}split${keep}${raw}`);
    chain.push(`${raw}crop=${bw}:${bh}:${bx}:${by},gblur=sigma=18${blurred}`);
    chain.push(`${keep}${blurred}overlay=${bx}:${by}:enable='between(t,${f3(a)},${f3(z)})'${next}`);
    cur = next;
  }

  const filters = [];
  if (barH) filters.push(`crop=${W}:${OH}:0:${barH}`);
  seg.subtitles.forEach((s, j) => {
    let a = Math.max(0, s.from - seg.start), z = Math.min(dur, s.to - seg.start);
    if ((z - a) / seg.speed < MIN_SUB) {
      const want = MIN_SUB * seg.speed;
      z = Math.min(dur, a + want);
      if (z - a < want) a = Math.max(0, z - want);
      warnings.push(`seg${n} sub${j} stretched to ${f3((z - a) / seg.speed)}s on screen`);
    }
    const tf = textFile(`sub_${n}_${j}.txt`, s.text);
    const y = s.pos === 'top' ? '150' : `h-text_h-150`;
    filters.push(drawtext(tf, { size: 38, y, enable: `between(t,${f3(a)},${f3(z)})` }));
  });
  filters.push(`setpts=(PTS-STARTPTS)/${seg.speed}`, 'fps=30', 'format=yuv420p');
  chain.push(`${cur}${filters.join(',')}[v]`);

  const out = `seg${String(n).padStart(2, '0')}.mp4`;
  ff(['-ss', f3(seg.start), '-to', f3(seg.end), '-i', SRC[seg.src],
    '-filter_complex', chain.join(';'), '-map', '[v]', '-an',
    '-c:v', 'libx264', '-crf', '20', '-preset', 'slow', '-r', '30', '-video_track_timescale', '15360', out]);
  parts.push(out);
  console.log(`seg${n} ${seg.src} ${seg.start}-${seg.end} x${seg.speed} → ${f3(dur / seg.speed)}s`);
});

card('outro', edl.outro_card, 3.5);

fs.writeFileSync(path.join(work, 'list.txt'), parts.map(p => `file '${p}'`).join('\n'));
const final = path.join(__dirname, outName);
ff(['-f', 'concat', '-safe', '0', '-i', 'list.txt', '-c', 'copy', '-movflags', '+faststart', final]);
warnings.forEach(w => console.log('WARN', w));
const probe = spawnSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration,size', '-of', 'csv=p=0', final], { encoding: 'utf8' });
console.log('OUTPUT', final, probe.stdout.trim());
