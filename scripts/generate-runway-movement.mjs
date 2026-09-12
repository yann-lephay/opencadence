import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { access, mkdir, readFile, writeFile } from "node:fs/promises";
import { basename, extname, join } from "node:path";

import RunwayML, { TaskFailedError } from "@runwayml/sdk";

const KEYCHAIN_SERVICES = [
  "com.usine.la-bonne-seance.runway-api.part-1",
  "com.usine.la-bonne-seance.runway-api.part-2",
];
const KEYCHAIN_ACCOUNT = "runwayml-api-secret";

function readArguments(argv) {
  const values = new Map();

  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];

    if (!key?.startsWith("--") || value === undefined) {
      throw new Error(`Argument invalide près de ${key ?? "la fin de la commande"}.`);
    }

    values.set(key.slice(2), value);
  }

  return values;
}

function required(argumentsMap, name) {
  const value = argumentsMap.get(name);
  if (!value) {
    throw new Error(`Argument requis manquant : --${name}`);
  }
  return value;
}

function readApiKey() {
  const result = KEYCHAIN_SERVICES.map((service) =>
    execFileSync(
      "/usr/bin/security",
      [
        "find-generic-password",
        "-a",
        KEYCHAIN_ACCOUNT,
        "-s",
        service,
        "-w",
      ],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    ).trim(),
  ).join("");

  if (!/^key_[0-9a-f]{128}$/i.test(result)) {
    throw new Error("La clé Runway du Trousseau n’a pas le format attendu.");
  }

  return result;
}

function mediaTypeFor(path) {
  const extension = extname(path).toLowerCase();
  if (extension === ".png") return "image/png";
  if (extension === ".jpg" || extension === ".jpeg") return "image/jpeg";
  if (extension === ".webp") return "image/webp";
  throw new Error(`Format d’image non pris en charge : ${extension}`);
}

async function assertMissing(path) {
  try {
    await access(path);
  } catch (error) {
    if (error?.code === "ENOENT") return;
    throw error;
  }

  throw new Error(`La sortie existe déjà et ne sera pas écrasée : ${path}`);
}

async function main() {
  const args = readArguments(process.argv.slice(2));
  const imagePath = required(args, "image");
  const outputDirectory = required(args, "out");
  const promptText = required(args, "prompt");
  const model = args.get("model") ?? "gen4.5";
  const ratio = args.get("ratio") ?? "960:960";
  const duration = Number(args.get("duration") ?? "4");
  const seed = Number(args.get("seed") ?? "2793775000");
  const videoPath = join(outputDirectory, "dumbbell_floor_press_gen45_v03.mp4");
  const provenancePath = join(outputDirectory, "generation.json");

  if (!Number.isInteger(duration) || duration < 2 || duration > 10) {
    throw new Error("La durée doit être un entier compris entre 2 et 10 secondes.");
  }

  if (!Number.isInteger(seed) || seed < 0 || seed > 4_294_967_295) {
    throw new Error("Le seed doit être un entier non signé sur 32 bits.");
  }

  await mkdir(outputDirectory, { recursive: true });
  await assertMissing(videoPath);
  await assertMissing(provenancePath);

  const image = await readFile(imagePath);
  if (image.byteLength > 5 * 1024 * 1024) {
    throw new Error("L’image dépasse la limite Runway de 5 Mio.");
  }

  const sourceSha256 = createHash("sha256").update(image).digest("hex");
  const promptImage = `data:${mediaTypeFor(imagePath)};base64,${image.toString("base64")}`;
  const client = new RunwayML({ apiKey: readApiKey() });

  const pendingTask = client.imageToVideo.create({
    model,
    promptImage,
    promptText,
    ratio,
    duration,
    seed,
    outputFormat: "mp4",
  });

  const task = await pendingTask.waitForTaskOutput({ timeout: 10 * 60 * 1000 });
  const videoUrl = task.output[0];
  if (!videoUrl) {
    throw new Error("Runway a terminé la tâche sans fournir de vidéo.");
  }

  const response = await fetch(videoUrl);
  if (!response.ok) {
    throw new Error(`Téléchargement impossible (${response.status}).`);
  }

  await writeFile(videoPath, Buffer.from(await response.arrayBuffer()));

  const provenance = {
    movementId: "dumbbell_floor_press",
    sourceImage: basename(imagePath),
    sourceBytes: image.byteLength,
    sourceSha256,
    model,
    ratio,
    requestedDuration: duration,
    seed,
    promptText,
    outputFormat: "mp4",
    taskId: task.id,
    taskCreatedAt: task.createdAt,
    completedAt: new Date().toISOString(),
    chargedCredits: task.cost.credits,
    outputFile: basename(videoPath),
  };

  await writeFile(
    provenancePath,
    `${JSON.stringify(provenance, null, 2)}\n`,
    "utf8",
  );

  console.log(
    JSON.stringify({
      status: task.status,
      taskId: task.id,
      chargedCredits: task.cost.credits,
      output: videoPath,
      provenance: provenancePath,
    }),
  );
}

main().catch((error) => {
  if (error instanceof TaskFailedError) {
    console.error(
      JSON.stringify({
        status: error.taskDetails.status,
        taskId: error.taskDetails.id,
        chargedCredits: error.taskDetails.cost?.credits ?? null,
        failureCode: error.taskDetails.failureCode ?? null,
        failure: error.taskDetails.failure,
      }),
    );
  } else if (error instanceof RunwayML.APIError) {
    console.error(
      JSON.stringify({
        status: error.status,
        error: error.name,
        message: error.message,
      }),
    );
  } else {
    console.error(error instanceof Error ? error.message : String(error));
  }
  process.exitCode = 1;
});
