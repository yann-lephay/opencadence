import fs from "node:fs";
import path from "node:path";

const root = path.dirname(new URL(import.meta.url).pathname);
const framesDirectory = path.join(root, "frames");
fs.mkdirSync(framesDirectory, { recursive: true });

const palette = {
  ink: "#012F2B",
  green: "#0D5A50",
  skin: "#B87855",
  skinLight: "#D2946C",
  skinShade: "#8E543D",
  paper: "#ECE5F0",
};

const mix = (start, end, amount) => ({
  x: start.x + (end.x - start.x) * amount,
  y: start.y + (end.y - start.y) * amount,
});

const limb = (start, end, startWidth, endWidth, fill, outline = "none") => {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const length = Math.hypot(dx, dy);
  const nx = -dy / length;
  const ny = dx / length;
  const p1 = { x: start.x + nx * startWidth / 2, y: start.y + ny * startWidth / 2 };
  const p2 = { x: end.x + nx * endWidth / 2, y: end.y + ny * endWidth / 2 };
  const p3 = { x: end.x - nx * endWidth / 2, y: end.y - ny * endWidth / 2 };
  const p4 = { x: start.x - nx * startWidth / 2, y: start.y - ny * startWidth / 2 };
  return `<path d="M${p1.x.toFixed(1)} ${p1.y.toFixed(1)} L${p2.x.toFixed(1)} ${p2.y.toFixed(1)} Q${end.x.toFixed(1)} ${end.y.toFixed(1)} ${p3.x.toFixed(1)} ${p3.y.toFixed(1)} L${p4.x.toFixed(1)} ${p4.y.toFixed(1)} Q${start.x.toFixed(1)} ${start.y.toFixed(1)} ${p1.x.toFixed(1)} ${p1.y.toFixed(1)}Z" fill="${fill}" stroke="${outline}" stroke-width="1.5" stroke-linejoin="round"/>`;
};

const dumbbell = (center, far) => {
  const scale = far ? 0.88 : 0.95;
  return `<g transform="translate(${center.x.toFixed(1)} ${center.y.toFixed(1)}) rotate(-8) scale(${scale})">
    <ellipse cx="2" cy="11" rx="36" ry="7" fill="#012F2B" opacity="0.16"/>
    <rect x="-24" y="-5" width="48" height="10" rx="5" fill="${palette.paper}" stroke="${palette.ink}" stroke-width="2.5"/>
    <path d="M-36-16 L-24-20 L-14-11 L-14 11 L-25 20 L-37 15 L-43 0Z" fill="${palette.ink}"/>
    <path d="M36-16 L24-20 L14-11 L14 11 L25 20 L37 15 L43 0Z" fill="${palette.ink}"/>
    <path d="M-33-10 L-25-13 L-19-8 L-19 8 L-26 13 L-34 9 L-38 0Z" fill="${palette.green}"/>
    <path d="M33-10 L25-13 L19-8 L19 8 L26 13 L34 9 L38 0Z" fill="${palette.green}"/>
    <ellipse cx="0" cy="1" rx="8" ry="11" fill="${palette.skinLight}" stroke="${palette.ink}" stroke-width="2"/>
  </g>`;
};

const arm = ({ shoulder, elbow, wrist, far }) => {
  const skin = far ? palette.skinShade : palette.skin;
  const sleeveEnd = mix(shoulder, elbow, 0.30);
  return `<g opacity="${far ? 0.94 : 1}">
    ${limb({ x: shoulder.x + 4, y: shoulder.y + 6 }, { x: elbow.x + 4, y: elbow.y + 6 }, 29, 23, "#012F2B2E")}
    ${limb({ x: elbow.x + 4, y: elbow.y + 6 }, { x: wrist.x + 4, y: wrist.y + 6 }, 23, 17, "#012F2B2E")}
    ${limb(shoulder, elbow, 28, 22, skin)}
    <ellipse cx="${elbow.x.toFixed(1)}" cy="${elbow.y.toFixed(1)}" rx="11.5" ry="10.5" fill="${skin}"/>
    ${limb(elbow, wrist, 22, 16, skin)}
    ${limb(shoulder, sleeveEnd, 32, 27, far ? palette.ink : palette.green)}
    <path d="M${mix(elbow, wrist, 0.18).x.toFixed(1)} ${mix(elbow, wrist, 0.18).y.toFixed(1)} Q${mix(elbow, wrist, 0.52).x.toFixed(1)} ${(mix(elbow, wrist, 0.52).y - 3).toFixed(1)} ${mix(elbow, wrist, 0.78).x.toFixed(1)} ${mix(elbow, wrist, 0.78).y.toFixed(1)}" fill="none" stroke="${palette.skinLight}" stroke-width="2" opacity="0.55" stroke-linecap="round"/>
    ${dumbbell(wrist, far)}
  </g>`;
};

const poses = {
  top: {
    far: {
      shoulder: { x: 177, y: 304 },
      elbow: { x: 174, y: 221 },
      wrist: { x: 170, y: 137 },
    },
    near: {
      shoulder: { x: 235, y: 317 },
      elbow: { x: 238, y: 231 },
      wrist: { x: 242, y: 146 },
    },
  },
  bottom: {
    far: {
      shoulder: { x: 177, y: 304 },
      elbow: { x: 120, y: 263 },
      wrist: { x: 121, y: 187 },
    },
    near: {
      shoulder: { x: 235, y: 317 },
      elbow: { x: 286, y: 352 },
      wrist: { x: 286, y: 276 },
    },
  },
};

const render = (amount) => {
  const far = {
    shoulder: poses.top.far.shoulder,
    elbow: mix(poses.top.far.elbow, poses.bottom.far.elbow, amount),
    wrist: mix(poses.top.far.wrist, poses.bottom.far.wrist, amount),
    far: true,
  };
  const near = {
    shoulder: poses.top.near.shoulder,
    elbow: mix(poses.top.near.elbow, poses.bottom.near.elbow, amount),
    wrist: mix(poses.top.near.wrist, poses.bottom.near.wrist, amount),
    far: false,
  };

  return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="512" height="512" viewBox="0 0 512 512">
    <defs>
      <filter id="armTexture" x="-20%" y="-20%" width="140%" height="140%">
        <feTurbulence type="fractalNoise" baseFrequency="0.38" numOctaves="2" seed="23" result="noise"/>
        <feColorMatrix in="noise" values="0.55 0 0 0 0.15  0 0.45 0 0 0.12  0 0 0.35 0 0.08  0 0 0 0.16 0" result="tintedNoise"/>
        <feComposite in="tintedNoise" in2="SourceGraphic" operator="in" result="texture"/>
        <feBlend in="SourceGraphic" in2="texture" mode="multiply"/>
      </filter>
    </defs>
    <image x="0" y="0" width="512" height="512" preserveAspectRatio="xMidYMid slice" xlink:href="base_plate.png"/>
    <g filter="url(#armTexture)">
      ${arm(far)}
      ${arm(near)}
    </g>
  </svg>`;
};

const descent = Array.from({ length: 9 }, (_, index) => index / 8);
const sequence = [...descent, ...descent.slice(1, -1).reverse()];

sequence.forEach((linearAmount, index) => {
  const easedAmount = (1 - Math.cos(Math.PI * linearAmount)) / 2;
  const filename = `frame_${String(index).padStart(2, "0")}.svg`;
  fs.writeFileSync(path.join(framesDirectory, filename), render(easedAmount));
});

console.log(`Generated ${sequence.length} locked-background frames.`);
