import fs from "node:fs";
import path from "node:path";

const outputDirectory = new URL("./frames/", import.meta.url);
fs.mkdirSync(outputDirectory, { recursive: true });

const palette = {
  ink: "#012F2B",
  green: "#0D5A50",
  orange: "#E98A15",
  plum: "#59114D",
  cream: "#F4EEE4",
  paper: "#ECE5F0",
  skin: "#B97955",
  skinShade: "#92583E",
};

const project = ({ x, y, z }) => ({
  x: 222 + 174 * x + 92 * y,
  y: 302 + 30 * x + 42 * y - 112 * z,
});

const interpolate = (start, end, amount) => ({
  x: start.x + (end.x - start.x) * amount,
  y: start.y + (end.y - start.y) * amount,
  z: start.z + (end.z - start.z) * amount,
});

const point = (value) => `${value.x.toFixed(1)},${value.y.toFixed(1)}`;

const arm = ({ shoulder, elbow, wrist, far = false }) => {
  const s = project(shoulder);
  const e = project(elbow);
  const w = project(wrist);
  const shade = far ? palette.skinShade : palette.skin;
  const opacity = far ? 0.9 : 1;
  return `
    <g opacity="${opacity}">
      <path d="M ${point(s)} L ${point(e)}" stroke="${palette.ink}" stroke-width="26" stroke-linecap="round"/>
      <path d="M ${point(s)} L ${point(e)}" stroke="${shade}" stroke-width="20" stroke-linecap="round"/>
      <path d="M ${point(e)} L ${point(w)}" stroke="${palette.ink}" stroke-width="24" stroke-linecap="round"/>
      <path d="M ${point(e)} L ${point(w)}" stroke="${shade}" stroke-width="18" stroke-linecap="round"/>
      <circle cx="${e.x}" cy="${e.y}" r="11" fill="${shade}" stroke="${palette.ink}" stroke-width="3"/>
      ${dumbbell(w, far)}
    </g>`;
};

const dumbbell = (wrist, far) => {
  const scale = far ? 0.94 : 1;
  return `
    <g transform="translate(${wrist.x.toFixed(1)} ${wrist.y.toFixed(1)}) scale(${scale}) rotate(-8)">
      <rect x="-22" y="-5" width="44" height="10" rx="4" fill="${palette.paper}" stroke="${palette.ink}" stroke-width="3"/>
      <path d="M-30-15 L-19-19 L-11-11 L-12 11 L-20 18 L-31 14 L-36 0Z" fill="${palette.ink}"/>
      <path d="M30-15 L19-19 L11-11 L12 11 L20 18 L31 14 L36 0Z" fill="${palette.ink}"/>
      <path d="M-29-10 L-21-13 L-16-8 L-17 8 L-22 12 L-30 9Z" fill="${palette.green}"/>
      <path d="M29-10 L21-13 L16-8 L17 8 L22 12 L30 9Z" fill="${palette.green}"/>
      <ellipse cx="0" cy="1" rx="8" ry="10" fill="${palette.skin}" stroke="${palette.ink}" stroke-width="2"/>
    </g>`;
};

const body = `
  <g id="body">
    <ellipse cx="262" cy="352" rx="178" ry="24" fill="#012F2B" opacity="0.16"/>
    <path d="M142 303 Q180 264 237 273 Q295 282 342 312 L329 355 Q265 347 201 342 Q161 338 137 321Z" fill="${palette.ink}" stroke="#001D1A" stroke-width="4"/>
    <path d="M286 317 Q333 306 362 273 Q378 254 393 242" fill="none" stroke="${palette.ink}" stroke-width="35" stroke-linecap="round"/>
    <path d="M302 337 Q356 341 397 324 Q420 314 442 321" fill="none" stroke="${palette.ink}" stroke-width="34" stroke-linecap="round"/>
    <path d="M287 317 Q333 306 362 273 Q378 254 393 242" fill="none" stroke="${palette.skin}" stroke-width="27" stroke-linecap="round"/>
    <path d="M302 337 Q356 341 397 324 Q420 314 442 321" fill="none" stroke="${palette.skin}" stroke-width="26" stroke-linecap="round"/>
    <path d="M372 254 Q390 240 407 254 L420 270 L399 283 L379 271Z" fill="${palette.ink}"/>
    <path d="M422 307 Q452 307 469 323 L456 343 L417 338Z" fill="${palette.ink}"/>
    <path d="M408 271 L421 267" stroke="${palette.plum}" stroke-width="5" stroke-linecap="round"/>
    <path d="M455 342 L468 329" stroke="${palette.plum}" stroke-width="5" stroke-linecap="round"/>
    <path d="M276 304 Q323 309 343 325 L332 357 Q299 352 269 346Z" fill="${palette.green}" stroke="${palette.ink}" stroke-width="4"/>
    <path d="M141 302 Q111 286 88 305 Q72 320 84 340 Q101 357 129 344 Q148 334 151 318Z" fill="${palette.skin}" stroke="${palette.ink}" stroke-width="4"/>
    <path d="M83 333 Q72 306 91 292 Q111 278 139 302 Q124 306 115 321 Q99 328 83 333Z" fill="${palette.ink}"/>
    <path d="M95 322 Q105 316 116 319" fill="none" stroke="${palette.ink}" stroke-width="3" stroke-linecap="round"/>
    <circle cx="113" cy="312" r="2.8" fill="${palette.ink}"/>
    <path d="M124 325 Q130 328 136 326" fill="none" stroke="${palette.ink}" stroke-width="2.5" stroke-linecap="round"/>
  </g>`;

const background = `
  <defs>
    <filter id="paper" x="-10%" y="-10%" width="120%" height="120%">
      <feTurbulence type="fractalNoise" baseFrequency="0.75" numOctaves="2" seed="19" result="noise"/>
      <feColorMatrix in="noise" values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 .075 0"/>
    </filter>
  </defs>
  <rect width="512" height="512" fill="${palette.cream}"/>
  <path d="M0 0 H512 V155 Q400 126 296 144 Q154 166 0 127Z" fill="${palette.paper}"/>
  <path d="M0 414 L512 366 V512 H0Z" fill="#D9C8B8"/>
  <path d="M41 217 L427 185 L494 382 L88 421Z" fill="${palette.orange}" opacity="0.92" stroke="${palette.ink}" stroke-width="5"/>
  <g transform="translate(414 92)">
    <path d="M18 94 C17 57 19 34 22 9" stroke="${palette.ink}" stroke-width="5" fill="none"/>
    <ellipse cx="3" cy="37" rx="17" ry="8" transform="rotate(-29 3 37)" fill="${palette.green}"/>
    <ellipse cx="35" cy="29" rx="18" ry="9" transform="rotate(32 35 29)" fill="${palette.green}"/>
    <ellipse cx="6" cy="61" rx="20" ry="9" transform="rotate(-13 6 61)" fill="${palette.ink}"/>
    <ellipse cx="39" cy="55" rx="20" ry="9" transform="rotate(18 39 55)" fill="${palette.ink}"/>
    <path d="M-2 91 H45 L39 128 H5Z" fill="${palette.plum}"/>
  </g>
  <rect width="512" height="512" filter="url(#paper)" opacity="0.55"/>`;

const top = {
  near: {
    shoulder: { x: 0.03, y: 0.27, z: 0.30 },
    elbow: { x: 0.08, y: 0.46, z: 0.92 },
    wrist: { x: 0.09, y: 0.54, z: 1.49 },
  },
  far: {
    shoulder: { x: -0.02, y: -0.28, z: 0.31 },
    elbow: { x: 0.03, y: -0.45, z: 0.91 },
    wrist: { x: 0.06, y: -0.54, z: 1.47 },
  },
};

const bottom = {
  near: {
    shoulder: { x: 0.03, y: 0.27, z: 0.30 },
    elbow: { x: 0.12, y: 0.78, z: 0.24 },
    wrist: { x: 0.10, y: 0.77, z: 0.94 },
  },
  far: {
    shoulder: { x: -0.02, y: -0.28, z: 0.31 },
    elbow: { x: 0.09, y: -0.77, z: 0.24 },
    wrist: { x: 0.07, y: -0.76, z: 0.92 },
  },
};

const render = (amount) => {
  const near = {
    shoulder: top.near.shoulder,
    elbow: interpolate(top.near.elbow, bottom.near.elbow, amount),
    wrist: interpolate(top.near.wrist, bottom.near.wrist, amount),
  };
  const far = {
    shoulder: top.far.shoulder,
    elbow: interpolate(top.far.elbow, bottom.far.elbow, amount),
    wrist: interpolate(top.far.wrist, bottom.far.wrist, amount),
  };

  return `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
    ${background}
    ${arm({ ...far, far: true })}
    ${body}
    ${arm({ ...near })}
  </svg>`;
};

const descent = Array.from({ length: 9 }, (_, index) => index / 8);
const sequence = [...descent, ...descent.slice(1, -1).reverse()];

sequence.forEach((linearAmount, index) => {
  const easedAmount = (1 - Math.cos(Math.PI * linearAmount)) / 2;
  const filename = `frame_${String(index).padStart(2, "0")}.svg`;
  fs.writeFileSync(path.join(outputDirectory.pathname, filename), render(easedAmount));
});

console.log(`Generated ${sequence.length} deterministic SVG frames.`);
