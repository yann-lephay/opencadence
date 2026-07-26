import { promises as fs } from "node:fs";
import path from "node:path";
import { defaultCadenceState } from "./default-state";
import type { CadenceState } from "./types";

const dataPath = path.join(process.cwd(), "data", "state.json");

export async function readState(): Promise<CadenceState> {
  try {
    const raw = await fs.readFile(dataPath, "utf8");
    const state = JSON.parse(raw) as CadenceState;
    if (state.onboardingComplete === undefined) state.onboardingComplete = true;
    return state;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    const initialState = defaultCadenceState();
    await writeState(initialState);
    return initialState;
  }
}

export async function writeState(state: CadenceState): Promise<void> {
  await fs.mkdir(path.dirname(dataPath), { recursive: true });
  const temporaryPath = `${dataPath}.tmp`;
  await fs.writeFile(temporaryPath, `${JSON.stringify(state, null, 2)}\n`, "utf8");
  await fs.rename(temporaryPath, dataPath);
}
