#!/usr/bin/env node
// Explicit prototype selections only. No app or release manifest writes.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const mediaRoot = resolve(root, 'prototypes/movement-media');
const standard = 'stop-motion-v01-candidates/frames';
const cycle = (id, indices, options = {}) => ({
  id, kind: 'cycle',
  sources: indices.map((index) => `${options.directory ?? standard}/frame_${String(index).padStart(2, '0')}.png`),
  notes: options.notes ?? [],
  visiblyDistinctPoses: options.visiblyDistinctPoses ?? indices.length,
});
const boardCycle = (id, indices, columns, rows, source = `candidate-v01/${id}_board.png`, visiblyDistinctPoses = indices.length) => ({
  id, kind: 'cycle',
  sources: indices.map(() => source),
  boardCellIndices: indices,
  crops: indices.map((index) => {
    const [x, width] = columns[(index - 1) % columns.length];
    const [y, height] = rows[Math.floor((index - 1) / columns.length)];
    return `${width}x${height}+${x}+${y}`;
  }),
  visiblyDistinctPoses,
  notes: ['Explicit board-cell selections received after independent visual review. Cell boundaries follow the actual grid, not an assumed equal-height grid. Full cell fitted inside a square; no anatomical interpolation or body crop.'],
});
const selections = [
  cycle('squat', [1, 2, 3, 4, 5, 6]),
  cycle('glute_bridge', [1, 4, 5, 6, 7, 8]),
  cycle('seated_dumbbell_overhead_press', [1, 4, 5, 6, 7, 8]),
  { id: 'supported_one_arm_row', kind: 'cycle', sources: ['01_start', '02_early', '03_late', '04_top'].map((name) => `stop-motion-v02-candidate-matrix/row3-frames/frame_${name}.png`), visiblyDistinctPoses: 4, notes: ['Four readable selected poses; no synthetic intermediates.'] },
  cycle('supported_calf_raise', [1, 4, 8], {
    directory: 'stop-motion-v01-candidates/frames-v02', visiblyDistinctPoses: 2,
    notes: ['Three source snapshots, but only two clearly distinct states: heels down and raised. The intermediate/high snapshots are close; do not advertise three distinct heights.'],
  }),
  cycle('push_up', [1, 2, 3, 4, 5], { notes: ['Excluded frame 06 following visual review.'] }),
  cycle('incline_push_up', [1, 2, 3, 4, 5, 6], { notes: ['Excluded frames 07 and 08 following visual review.'] }),
  cycle('assisted_split_squat', [1, 2, 3, 4], { notes: ['Excluded frame 05: rear-knee floor contact is visually ambiguous.'] }),
  cycle('split_squat', [1, 2, 3, 5], { notes: ['Excluded frame 04: rear knee appears at mat level. Frame 05 is used after 03; source numbering is not motion order.'] }),
  ...['front_plank', 'side_plank', 'elevated_front_plank'].map((id) => ({
    id, kind: 'isometric', sources: [`candidate-v01/${id}_hold.png`], visiblyDistinctPoses: 1,
    notes: ['Static hold demonstration, not a repetition or breathing animation.'],
  })),
  boardCycle('dumbbell_biceps_curl', [1, 2, 3, 4, 5, 8], [[7, 306], [318, 307], [630, 306], [942, 306]], [[5, 335], [343, 335]]),
  boardCycle('dumbbell_lateral_raise', [1, 2, 3, 4, 6, 7, 8], [[3, 310], [315, 310], [629, 309], [941, 310]], [[3, 311], [315, 312]]),
  boardCycle('supported_single_leg_calf_raise', [5, 6, 7, 8], [[9, 433], [450, 432], [891, 432], [1331, 434]], [[9, 431], [448, 430]]),
  boardCycle('band_lat_pulldown_over_bar', [1, 2, 3, 4, 5, 6, 7], [[10, 370], [392, 371], [772, 371], [1154, 371]], [[10, 497], [518, 496]]),
  boardCycle('chair_sit_to_stand', [14, 13, 2, 5, 7], [[9, 301], [320, 303], [632, 302], [944, 302]], [[8, 305], [320, 305], [634, 304], [947, 302]], 'stop-motion-v02-candidates/chair_sit_to_stand_contact_sheet_v02.png'),
  boardCycle('seated_band_row', [1, 2, 3, 4], [[6, 303], [318, 304], [632, 303], [945, 303]], [[6, 306]], 'stop-motion-v03-candidates/seated_band_row_contact_sheet_v03.png', 2),
  boardCycle('bent_over_dumbbell_row', [5, 6, 7, 8], [[5, 306], [316, 308], [630, 307], [942, 307]], [[6, 335], [346, 332]], 'stop-motion-v01-candidates/bent_over_dumbbell_row_contact_sheet_v02.png'),
  {
    ...boardCycle('wall_hip_hinge', [1, 2, 5, 6, 7], [[12, 426], [453, 426], [895, 426], [1337, 426]], [[11, 431], [453, 423]], 'candidate-v03/wall_hip_hinge_board.png', null),
    status: 'experimental_reselection_pending_review',
    notes: ['experimental_reselection_pending_review', 'Five selected snapshots; anatomically distinct pose count remains pending independent review.', 'Frames 3 and 4 excluded. Short hinge reselection is an experiment, not visual approval.'],
  },
  {
    id: 'single_arm_overhead_press', kind: 'cycle',
    sources: [
      'stop-motion-v01-candidates/single_arm_overhead_press_contact_sheet_v02.png',
      'stop-motion-v01-candidates/single_arm_overhead_press_contact_sheet_v02.png',
      'intermediate-v03/intermediate.png',
      'stop-motion-v01-candidates/single_arm_overhead_press_contact_sheet_v02.png',
    ],
    boardCellIndices: [1, 6, null, 9],
    crops: ['299x303+10+10', '300x303+321+323', null, '299x302+10+638'],
    visiblyDistinctPoses: 4,
    notes: ['Explicit independently reviewed mixed-source selection: board cells 1, 6, intermediate-v03, then cell 9.', 'Slight shoe-tip clipping exists in the sources and was accepted as non-blocking for this overhead-press prototype; not introduced as an intentional crop.', 'No generated intermediate beyond the separately reviewed intermediate-v03 source.'],
  },
];

const requested = process.argv.slice(2);
if (requested.includes('--list')) {
  if (requested.length !== 1) throw new Error('Use --list alone.');
  console.log(selections.map(({ id }) => id).join('\n'));
  process.exit(0);
}
if (requested.length === 0) throw new Error('Specify one or more listed movement IDs, or --all. Use --list to inspect.');
const fromFile = requested[0] === '--selection-file';
if (fromFile && requested.length < 2) throw new Error('Use --selection-file <JSON path> [movement IDs].');
let jobs = fromFile
  ? JSON.parse(readFileSync(resolve(root, requested[1]), 'utf8'))
  : requested.length === 1 && requested[0] === '--all'
  ? selections
  : requested.map((id) => {
    const selection = selections.find((entry) => entry.id === id);
    if (!selection) throw new Error(`Not an explicitly reviewed selection: ${id}`);
    return selection;
  });
if (!Array.isArray(jobs) || !jobs.length) throw new Error('Expected a non-empty explicit selection array.');
if (fromFile && requested.length > 2) jobs = requested.slice(2).map((id) => {
  const job = jobs.find((entry) => entry.id === id);
  if (!job) throw new Error(`Not an explicitly reviewed selection: ${id}`);
  return job;
});
if (new Set(jobs.map(({ id }) => id)).size !== jobs.length) throw new Error('Duplicate requested movement.');
const canonicalIds = new Set(JSON.parse(readFileSync(resolve(mediaRoot, 'catalog-review.json'), 'utf8')).movements.map((entry) => entry.movementId));

const run = (command, args) => execFileSync(command, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 8 * 1024 * 1024 });
for (const job of jobs) {
  if (!canonicalIds.has(job.id)) throw new Error(`Unknown movement: ${job.id}`);
  if (!/^[a-z0-9-]+$/.test(job.outputDirectory ?? 'review-v02')) throw new Error('Invalid output directory name.');
  if (!Array.isArray(job.sources) || !job.sources.length) throw new Error(`${job.id}: no sources.`);
  const duration = job.durationSeconds ?? 4;
  if (!Number.isFinite(duration) || duration < 1 || duration > 12 || Math.abs(duration * 30 - Math.round(duration * 30)) > 1e-7) throw new Error(`${job.id}: durationSeconds must be 1–12 seconds aligned to 30 fps.`);
  if (job.sequence && (!Array.isArray(job.sequence) || !job.sequence.length || job.sequence.some((index) => !Number.isInteger(index) || index < 0 || index >= job.sources.length))) throw new Error(`${job.id}: invalid explicit sequence.`);
  if (job.fallbackIndices && (!Array.isArray(job.fallbackIndices) || !job.fallbackIndices.length || job.fallbackIndices.some((index) => !Number.isInteger(index) || index < 0 || index >= job.sources.length))) throw new Error(`${job.id}: invalid fallback indices.`);
  if (fromFile && !job.sequence) throw new Error('New selections require an explicit sequence; do not infer a reversed movement.');
  if (existsSync(resolve(mediaRoot, job.id, job.outputDirectory ?? 'review-v02'))) throw new Error(`${job.id}: output already exists; refusing to overwrite.`);
  for (const source of job.sources) {
    if (source.startsWith('/') || source.split('/').includes('..')) throw new Error('Source must be movement-relative.');
    if (!existsSync(resolve(mediaRoot, job.id, source))) throw new Error(`Missing source: ${job.id}/${source}`);
  }
}

for (const job of jobs) {
  const outputDirectory = job.outputDirectory ?? 'review-v02';
  const durationSeconds = job.durationSeconds ?? 4;
  const encodedFrames = Math.round(durationSeconds * 30);
  const output = resolve(mediaRoot, job.id, outputDirectory);
  mkdirSync(resolve(output, 'frames'), { recursive: true });
  const frames = job.sources.map((source, index) => {
    const filename = `frames/pose_${String(index + 1).padStart(2, '0')}.png`;
    // Fit within a fixed square; never crop anatomy or alter relative frame scale.
    const crop = job.crops?.[index] ? ['-crop', job.crops[index], '+repage'] : [];
    run('magick', [resolve(mediaRoot, job.id, source), ...crop, '-resize', '612x612', '-background', '#eee1cb', '-gravity', 'center', '-extent', '612x612', resolve(output, filename)]);
    return filename;
  });
  const forward = frames.map((_, index) => index);
  const sequence = job.sequence ?? (job.kind === 'isometric' ? [0] : [...forward, ...forward.slice(0, -1).reverse()]);
  // Exact frame-aligned duration at 30 fps; dwell frames are not new poses.
  const ticks = sequence.map(() => Math.floor(encodedFrames / sequence.length));
  for (let index = 0; index < encodedFrames % sequence.length; index += 1) ticks[index] += 1;
  const timeline = ['ffconcat version 1.0'];
  sequence.forEach((index, step) => timeline.push(`file '${frames[index]}'`, `duration ${(ticks[step] / 30).toFixed(9)}`));
  timeline.push(`file '${frames[sequence.at(-1)]}'`);
  writeFileSync(resolve(output, 'timeline.ffconcat'), `${timeline.join('\n')}\n`, { flag: 'wx' });
  const suffix = outputDirectory.replaceAll('-', '_');
  const video = `${job.id}_${suffix}.mp4`;
  const poster = `${job.id}_poster_${suffix}.webp`;
  const fallback = `${job.id}_fallback_${suffix}.webp`;
  run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-n', '-f', 'concat', '-safe', '1', '-i', resolve(output, 'timeline.ffconcat'), '-vf', 'fps=30,setsar=1', '-frames:v', String(encodedFrames), '-t', String(durationSeconds), '-an', '-c:v', 'libx264', '-crf', '18', '-preset', 'medium', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', resolve(output, video)]);
  const fallbackIndices = job.fallbackIndices ?? (job.kind === 'isometric' ? [0] : [0, Math.floor((frames.length - 1) / 2), frames.length - 1]);
  run('magick', [resolve(output, frames.at(-1)), '-quality', '90', resolve(output, poster)]);
  run('magick', [...fallbackIndices.map((index) => resolve(output, frames[index])), '+append', '-quality', '90', resolve(output, fallback)]);
  const probe = JSON.parse(run('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=codec_name,width,height,nb_frames:format=duration', '-of', 'json', resolve(output, video)]));
  const stream = probe.streams[0];
  if (stream.codec_name !== 'h264' || stream.width !== 612 || stream.height !== 612 || Number(stream.nb_frames) !== encodedFrames || Math.abs(Number(probe.format.duration) - durationSeconds) > 0.01) {
    throw new Error(`${job.id}: encoded output failed technical checks.`);
  }
  const metadata = {
    movementId: job.id, status: job.status ?? 'review_candidate_not_release', motionKind: job.kind,
    playback: job.kind === 'one_way' ? 'single_pass' : 'loop_review',
    sources: job.sources, boardCellIndices: job.boardCellIndices ?? null, boardCellCrops: job.crops ?? null,
    uniqueSourceFrames: frames.length, visiblyDistinctPoses: job.visiblyDistinctPoses,
    displayedSteps: sequence.length, sequenceSourceIndices: sequence.map((index) => index + 1),
    encodedFrames, fps: 30, durationSeconds, width: 612, height: 612, codec: 'h264',
    reversePoseReuse: job.reversePoseReuse ?? (job.sequence ? new Set(sequence).size < sequence.length : job.kind === 'cycle'), interpolatedFrames: 0,
    video, poster, fallback, fallbackSourceIndices: fallbackIndices.map((index) => index + 1),
    notes: [...job.notes, 'Timing holds repeat encoded pixels, not unique anatomical poses.', 'Technical render only. Requires final visual review; not professional validation or product approval.'],
  };
  writeFileSync(resolve(output, 'metadata.json'), `${JSON.stringify(metadata, null, 2)}\n`, { flag: 'wx' });
  console.log(JSON.stringify({ movementId: job.id, directory: `${job.id}/${outputDirectory}`, uniqueSourceFrames: frames.length, visiblyDistinctPoses: job.visiblyDistinctPoses, displayedSteps: sequence.length, video, poster, fallback }));
}
