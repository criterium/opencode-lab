import type { Plugin } from "@opencode-ai/plugin"
import { readFileSync, readdirSync, existsSync, appendFileSync } from "fs"
import { join, extname, basename, dirname } from "path"
import { fileURLToPath } from "url"

// Resolve overrides/ relative to this file's real location
// (import.meta.url resolves symlinks; no dependency on ~/.config/opencode/)
const __dirname = dirname(fileURLToPath(import.meta.url))
const OVERRIDES_DIR = join(__dirname, "overrides")
const LOG_FILE = join(__dirname, "debug.log")
const DEBUG = process.env.OPENCODE_TOOLS_OVERRIDE_DEBUG === "1"

function log(msg: string) {
  if (!DEBUG) return
  try {
    appendFileSync(LOG_FILE, msg + "\n", "utf-8")
  } catch {
    // Silently ignore write errors (e.g. read-only filesystem)
  }
}

function loadOverrides(): Record<string, string> {
  const overrides: Record<string, string> = {}
  if (!existsSync(OVERRIDES_DIR)) {
    log("[opencode-tools-override] overrides/ not found — no overrides loaded")
    return overrides
  }

  let files: string[]
  try {
    files = readdirSync(OVERRIDES_DIR)
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    log(`[opencode-tools-override] cannot read overrides/: ${msg}`)
    return overrides
  }
  let loaded = 0
  for (const file of files) {
    if (extname(file) !== ".txt") continue
    const toolID = basename(file, ".txt")

    // Warn on duplicate toolIDs (last wins)
    if (toolID in overrides) {
      log(`[opencode-tools-override] duplicate override for "${toolID}" — using last file`)
    }

    try {
      const content = readFileSync(join(OVERRIDES_DIR, file), "utf-8")
      overrides[toolID] = content
      loaded++
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err)
      log(`[opencode-tools-override] error reading ${file}: ${msg}`)
    }
  }
  log(`[opencode-tools-override] loaded ${loaded} override(s)`)
  return overrides
}

const cache = loadOverrides()

export default (async () => ({
  "tool.definition": async (
    input: { toolID: string },
    output: { description: string; parameters: any }
  ) => {
    const override = cache[input.toolID]
    if (override !== undefined) {
      log(`[opencode-tools-override] applied override for "${input.toolID}"`)
      output.description = override
    }
  },
})) satisfies Plugin
