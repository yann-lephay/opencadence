export const originalEquipmentChoices = [
  "Barre de traction",
  "Barres de dips",
  "Rameur",
  "Gilet lesté 10 kg",
  "Haltères réglables 10–16 kg",
  "Haltères 6 kg",
  "Haltères 5 kg",
  "Poids 1 kg",
] as const;

export const equipmentChoices = [
  ...originalEquipmentChoices,
  "Élastiques de résistance",
  "Kettlebell",
  "Banc ou chaise stable",
  "Tapis de sol",
] as const;

export function profileHasEquipment(equipment: string[], pattern: RegExp) {
  return equipment.some((item) => pattern.test(item.toLowerCase()));
}
