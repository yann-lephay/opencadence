#!/usr/bin/env node
// Exact reviewed selections only; never promotes clinical/product release status.
import { readFileSync, existsSync, mkdirSync, copyFileSync, statSync, realpathSync } from 'node:fs';
import { resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

const root = fileURLToPath(new URL('../', import.meta.url));
const sourceRoot = resolve(root, 'prototypes/movement-media');
const targetRoot = resolve(root, 'ios/OpenCadence/OpenCadence/MovementMedia');
const selection = JSON.parse(readFileSync(resolve(sourceRoot, 'ios-accepted-selection-v01.json'), 'utf8'));
const check = process.argv.includes('--check');
if (process.argv.slice(2).some(x => x !== '--check')) throw new Error('Use no arguments to import, or --check.');
const ids = JSON.parse(readFileSync(resolve(sourceRoot, 'catalog-review.json'), 'utf8')).movements.map(x => x.movementId).sort();
if (JSON.stringify(selection.assets.map(x => x.id).sort()) !== JSON.stringify(ids)) throw new Error('Selection must cover every canonical movement exactly once.');
const hash = p => createHash('sha256').update(readFileSync(p)).digest('hex');
let bytes = 0;
const files = [];
for (const asset of selection.assets) {
  if (!['loop', 'hold', 'singlePass'].includes(asset.playback)) throw new Error(`${asset.id}: invalid playback`);
  for (const [kind, suffix] of [['video', 'main_v01.mp4'], ['poster', 'poster_v01.webp'], ['fallback', 'phases_v01.webp']]) {
    const source = realpathSync(resolve(sourceRoot, asset[kind]));
    if (relative(sourceRoot, source).startsWith('..') || !asset[kind].startsWith(`${asset.id}/`)) throw new Error('Source escapes movement directory.');
    const target = resolve(targetRoot, `${asset.id}_${suffix}`);
    if (kind === 'video') {
      const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', source]));
      const video = probe.streams.find(s => s.codec_type === 'video');
      if (video?.codec_name !== 'h264' || video.width !== video.height || probe.streams.some(s => s.codec_type === 'audio') || Number(probe.format.duration) !== 4) throw new Error(`${asset.id}: unexpected video format`);
      execFileSync('ffmpeg', ['-v', 'error', '-i', source, '-f', 'null', '-'], { stdio: 'pipe' });
    } else {
      execFileSync('magick', ['identify', '-quiet', source], { stdio: 'pipe' });
    }
    // Refuse implicit overwrite; a later approved replacement needs a deliberate revision.
    if (existsSync(target) && hash(source) !== hash(target)) throw new Error(`Different asset already installed: ${target}`);
    if (check && !existsSync(target)) throw new Error(`Missing bundled asset: ${target}`);
    files.push({ source, target });
    bytes += statSync(source).size;
  }
}
if (!check) {
  mkdirSync(targetRoot, { recursive: true });
  for (const file of files) if (!existsSync(file.target)) copyFileSync(file.source, file.target);
}
console.log(JSON.stringify({ mode: check ? 'verified' : 'imported', movements: ids.length, files: files.length, bytes, releaseApproved: false }));
