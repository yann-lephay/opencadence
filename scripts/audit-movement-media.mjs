#!/usr/bin/env node
// Read-only coverage/technical audit. Never promotes visual or release status.
import { readFileSync, statSync } from 'node:fs';
import { dirname, isAbsolute, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const mediaRoot = resolve(root, 'prototypes/movement-media');
const args = process.argv.slice(2);
if (args.some((arg) => arg !== '--report')) {
  console.error('Usage: node scripts/audit-movement-media.mjs [--report]');
  process.exit(1);
}

const report = {
  ok: false,
  scope: 'Coverage and technical metadata only; no visual, professional or release approval.',
  counts: { canonical: 0, records: 0, videos: 0, probedVideos: 0 },
  statuses: {},
  videos: [],
  errors: [],
};
const statuses = new Set(['unreviewed', 'missing', 'needs_fix', 'rejected', 'visual_candidate']);
const motionKinds = new Set(['cycle', 'isometric', 'one_way', 'gait', 'rowing']);

try {
  const source = readFileSync(resolve(root, 'ios/CadenceEngine/Sources/CadenceEngine/V2ProductConfiguration.swift'), 'utf8');
  // The current Swift add helper resolves movement ?? key.components("__").first.
  // Parse every literal add call, rather than maintaining a second canonical list.
  const additions = [...source.matchAll(/\badd\(\s*"([^"]+)"(?:\s*,\s*movement:\s*"([^"]+)")?/g)];
  const canonical = new Set(additions.map((match) => match[2] ?? match[1].split('__')[0]));
  report.counts.canonical = canonical.size;
  if (canonical.size !== 42) report.errors.push(`Expected exactly 42 canonical movement IDs, found ${canonical.size}.`);

  const inventory = JSON.parse(readFileSync(resolve(mediaRoot, 'catalog-review.json'), 'utf8'));
  if (inventory.schemaVersion !== 1 || !Array.isArray(inventory.movements)) {
    throw new Error('Expected schemaVersion 1 with a movements array.');
  }
  const seen = new Set();
  report.counts.records = inventory.movements.length;

  for (const movement of inventory.movements) {
    const id = movement.movementId;
    if (seen.has(id)) report.errors.push(`Duplicate movement ID: ${id}`);
    seen.add(id);
    if (!canonical.has(id)) report.errors.push(`Non-canonical movement ID: ${id}`);
    if (!statuses.has(movement.reviewStatus)) report.errors.push(`${id}: invalid reviewStatus.`);
    if (!motionKinds.has(movement.motionKind)) report.errors.push(`${id}: invalid motionKind.`);
    if (typeof movement.title !== 'string' || !movement.title.trim()) report.errors.push(`${id}: missing title.`);
    if (movement.uniquePoses !== null && (!Number.isInteger(movement.uniquePoses) || movement.uniquePoses < 1)) {
      report.errors.push(`${id}: uniquePoses must be a positive integer or null.`);
    }
    report.statuses[movement.reviewStatus] = (report.statuses[movement.reviewStatus] ?? 0) + 1;
    if (movement.reviewStatus === 'visual_candidate') {
      for (const field of ['video', 'poster', 'fallback']) {
        if (!movement[field]) report.errors.push(`${id}: visual candidate lacks ${field}.`);
      }
    }
    for (const field of ['video', 'poster', 'fallback', 'board']) {
      const filename = movement[field];
      if (filename === null) continue;
      if (typeof filename !== 'string' || !filename) {
        report.errors.push(`${id}: ${field} must be a relative path or null.`);
        continue;
      }
      const absolute = resolve(mediaRoot, filename);
      const withinRoot = relative(mediaRoot, absolute);
      if (isAbsolute(filename) || withinRoot === '..' || withinRoot.startsWith(`..${sep}`) || isAbsolute(withinRoot)) {
        report.errors.push(`${id}: ${field} path escapes movement-media root.`);
        continue;
      }
      try {
        if (!statSync(absolute).isFile()) throw new Error('not a file');
      } catch {
        report.errors.push(`${id}: missing ${field} file: ${filename}`);
        continue;
      }
      if (field !== 'video') continue;
      report.counts.videos += 1;
      const probe = spawnSync('ffprobe', [
        '-v', 'error', '-select_streams', 'v:0',
        '-show_entries', 'stream=codec_name,width,height:format=duration',
        '-of', 'json', absolute,
      ], { encoding: 'utf8', timeout: 15000, maxBuffer: 1024 * 1024 });
      if (probe.error || probe.status !== 0) {
        report.errors.push(`${id}: ffprobe failed: ${probe.error?.message ?? probe.stderr.trim()}`);
        continue;
      }
      try {
        const metadata = JSON.parse(probe.stdout);
        const stream = metadata.streams?.[0];
        const duration = Number(metadata.format?.duration);
        if (!stream?.codec_name || !(stream.width > 0) || !(stream.height > 0) || !(duration > 0)) {
          throw new Error('missing or invalid video metadata');
        }
        report.videos.push({ movementId: id, path: filename, duration, width: stream.width, height: stream.height, codec: stream.codec_name });
        if (movement.reviewStatus === 'visual_candidate' &&
            (stream.codec_name !== 'h264' || stream.width !== stream.height || duration < 3.5 || duration > 5)) {
          report.errors.push(`${id}: candidate is outside the current square H264 / 3.5–5s prototype envelope.`);
        }
        report.counts.probedVideos += 1;
      } catch (error) {
        report.errors.push(`${id}: ${error.message}`);
      }
    }
  }
  for (const id of canonical) {
    if (!seen.has(id)) report.errors.push(`Missing canonical movement ID: ${id}`);
  }
} catch (error) {
  report.errors.push(error.message);
}

report.ok = report.errors.length === 0;
if (args.includes('--report')) {
  console.log(JSON.stringify(report, null, 2));
} else {
  console.log(`Coverage/technical audit: ${report.ok ? 'PASS' : 'FAIL'}`);
  console.log(`Canonical IDs: ${report.counts.canonical}; records: ${report.counts.records}; existing videos: ${report.counts.videos}; probed: ${report.counts.probedVideos}.`);
  console.log(`Review statuses: ${JSON.stringify(report.statuses)}`);
  console.log(report.scope);
  for (const error of report.errors) console.error(error);
}
process.exitCode = report.ok ? 0 : 1;
