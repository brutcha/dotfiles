/**
 * OpenCode plugin adapter for RTK command rewriting.
 * `@rtkBinary@` is replaced by rtk.nix with the pinned RTK executable path.
 */
import { Plugin } from "@opencode/plugin"
import { execFile } from "node:child_process"
import { promisify } from "node:util"

const rewrite = promisify(execFile)

export default Plugin.define({
  id: "rtk.opencode-v2",
  async setup(ctx) {
    await ctx.tool.hook("execute.before", async (event) => {
      if (event.tool !== "shell") return
      if (!event.input || typeof event.input !== "object") return

      const input = event.input as { command?: unknown }
      if (typeof input.command !== "string" || input.command.length === 0) return

      try {
        const options = { encoding: "utf8" as const, maxBuffer: 1024 * 1024 }
        let stdout: string
        try {
          ;({ stdout } = await rewrite("@rtkBinary@", ["rewrite", input.command], options))
        } catch (error) {
          stdout =
            error && typeof error === "object" && "stdout" in error && typeof error.stdout === "string"
              ? error.stdout
              : ""
        }
        const rewritten = stdout.trim()
        if (rewritten && rewritten !== input.command) input.command = rewritten
      } catch {
        return
      }
    })
  },
})
