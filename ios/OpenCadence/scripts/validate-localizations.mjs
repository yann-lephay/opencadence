#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const catalogPath = path.join(root, "OpenCadence", "Localizable.xcstrings");
const projectPath = path.join(root, "OpenCadence.xcodeproj", "project.pbxproj");
const metadataRoot = path.join(root, "AppStoreMetadata");
const targetLocales = ["en", "es", "de"];
const metadataLocales = ["fr-FR", "en-US", "es-ES", "de-DE"];
const metadataFiles = [
  "name.txt",
  "subtitle.txt",
  "promotional_text.txt",
  "description.txt",
  "keywords.txt",
  "release_notes.txt",
  "privacy_url.txt",
  "support_url.txt",
];
const requiredKeys = [
  "20 min",
  "30 min",
  "45 min",
  "Préparer ma première séance",
  "Les séries déjà enregistrées restent conservées.",
  "Les exercices restants seront notés comme non terminés, sans dette ni punition.",
  "La Bonne Séance ne proposera que des mouvements faisables avec ce matériel. Tu pourras le modifier à tout moment.",
  "Une gêne de %lld sur 10 a été enregistrée. La série n’est pas comptée et ce mouvement ne peut pas reprendre dans cette séance.",
  "L’historique montre les faits enregistrés. Une tendance ne sera affichée qu’avec plusieurs séances comparables.",
  "%@ par mois",
  "%@ par an",
];

const errors = [];
const warnings = [];

function readText(file) {
  if (!fs.existsSync(file)) {
    errors.push(`Fichier manquant : ${path.relative(root, file)}`);
    return "";
  }
  return fs.readFileSync(file, "utf8");
}

function formatTokens(value) {
  return [...value.matchAll(/%(?:\d+\$)?(?:lld|ld|d|f|@)/g)]
    .map((match) => match[0].replace(/^%\d+\$/, "%"))
    .sort();
}

function sameTokens(source, translation) {
  return JSON.stringify(formatTokens(source)) === JSON.stringify(formatTokens(translation));
}

const catalogText = readText(catalogPath);
const projectText = readText(projectPath);
const catalog = catalogText ? JSON.parse(catalogText) : { strings: {} };

if (catalog.sourceLanguage !== "fr") {
  errors.push(`sourceLanguage doit être fr, trouvé : ${catalog.sourceLanguage ?? "absent"}`);
}

for (const locale of ["fr", "en", "es", "de"]) {
  if (!new RegExp(`(^|\\s|,)${locale}(,|\\s|$)`, "m").test(projectText)) {
    errors.push(`La région ${locale} manque dans knownRegions du projet Xcode.`);
  }
}
if (!/developmentRegion = fr;/.test(projectText)) {
  errors.push("developmentRegion doit rester fr dans le projet Xcode.");
}

for (const key of requiredKeys) {
  if (!catalog.strings[key]) errors.push(`Clé produit obligatoire absente : ${key}`);
}

for (const [key, entry] of Object.entries(catalog.strings)) {
  for (const locale of targetLocales) {
    const unit = entry.localizations?.[locale]?.stringUnit;
    if (!unit?.value?.trim()) {
      errors.push(`[${locale}] traduction absente : ${key}`);
      continue;
    }
    if (unit.state !== "translated") {
      errors.push(`[${locale}] état non traduit (${unit.state ?? "absent"}) : ${key}`);
    }
    if (!sameTokens(key, unit.value)) {
      errors.push(`[${locale}] placeholders incompatibles : ${key} -> ${unit.value}`);
    }
    if (key.includes("La Bonne Séance") && !unit.value.includes("La Bonne Séance")) {
      errors.push(`[${locale}] le nom de marque a été traduit ou altéré : ${key}`);
    }
  }
}

for (const locale of metadataLocales) {
  const localeRoot = path.join(metadataRoot, locale);
  for (const file of metadataFiles) {
    const filePath = path.join(localeRoot, file);
    const value = readText(filePath).trim();
    if (!value) errors.push(`[${locale}] métadonnée vide : ${file}`);
  }

  const name = readText(path.join(localeRoot, "name.txt")).trim();
  const subtitle = readText(path.join(localeRoot, "subtitle.txt")).trim();
  const promo = readText(path.join(localeRoot, "promotional_text.txt")).trim();
  const keywords = readText(path.join(localeRoot, "keywords.txt")).trim();
  if (name !== "La Bonne Séance") errors.push(`[${locale}] le nom public doit rester La Bonne Séance.`);
  if ([...name].length > 30) errors.push(`[${locale}] name.txt dépasse 30 caractères.`);
  if ([...subtitle].length > 30) errors.push(`[${locale}] subtitle.txt dépasse 30 caractères.`);
  if ([...promo].length > 170) errors.push(`[${locale}] promotional_text.txt dépasse 170 caractères.`);
  if ([...keywords].length > 100) errors.push(`[${locale}] keywords.txt dépasse 100 caractères.`);
  if (/\b(?:6[.,]99|39[.,]99)\b/.test(readText(path.join(localeRoot, "description.txt")))
      && !/App Store/i.test(readText(path.join(localeRoot, "description.txt")))) {
    warnings.push(`[${locale}] un prix est cité sans rappeler l'autorité du prix App Store local.`);
  }
}

if (warnings.length) {
  console.warn(warnings.map((item) => `WARN ${item}`).join("\n"));
}
if (errors.length) {
  console.error(errors.map((item) => `FAIL ${item}`).join("\n"));
  process.exit(1);
}

console.log(
  `PASS localisations : ${Object.keys(catalog.strings).length} clés, fr source/fallback, en/es/de complets, métadonnées ${metadataLocales.join(", ")}.`
);
