/**
 * Shared routing block for context-mode hooks.
 * Single source of truth — imported by pretooluse.mjs and sessionstart.mjs.
 *
 * Factory functions accept a tool namer `t(bareTool) => platformSpecificName`
 * so each platform gets correct tool names in guidance messages.
 *
 * Backward compat: static exports (ROUTING_BLOCK, READ_GUIDANCE, etc.)
 * default to claude-code naming convention.
 */

import { createToolNamer } from "./core/tool-naming.mjs";

// ── Factory functions ─────────────────────────────────────

export function createRoutingBlock(t, options = {}) {
  const { includeCommands = true, toolSearchBootstrap = false } = options;
  // Compact form: name the platform prefix once, then use bare ctx_* names.
  // Derive the prefix from the namer so non-claude-code platforms stay correct.
  const full = t("ctx_search");
  const prefix = full.slice(0, full.length - "ctx_search".length);
  const prefixNote = prefix ? ` Tool names below are shorthand; the callable names carry the prefix ${prefix} (e.g. ${full}).` : '';
  return `
<context_window_protection>
  Every byte a tool returns enters conversation memory and costs reasoning capacity for the rest of the session. Do the work in the context-mode sandbox and surface only the derived answer — program the analysis, do not read raw data into your conversation.${prefixNote}
${toolSearchBootstrap ? `
  Deferred-tool bootstrap: ctx_* schemas may not be loaded; before the first ctx_* call run ToolSearch(query: "select:${t("ctx_batch_execute")},${t("ctx_search")},${t("ctx_execute")},${t("ctx_execute_file")},${t("ctx_fetch_and_index")}"). If a ctx_* call fails as not-found, ToolSearch it and retry — never fall back to Bash/Read for that reason.
` : ''}
  Routing:
  - MEMORY: on resume/compaction, ctx_search(sort: "timeline") for prior decisions, errors, plans before asking the user.
  - GATHER: ctx_batch_execute(commands, queries) — parallel commands, each output auto-indexed; passed queries return matching sections in the same round trip. Descriptive labels improve search.
  - FOLLOW-UP: ctx_search(queries: [...]) — batch every question in one array; one round trip.
  - PROCESS: ctx_execute(language, code) | ctx_execute_file(path, language, code) — filter, count, parse, aggregate in the sandbox; only what you print enters the conversation.

  Boundaries:
  - Bash only to OBSERVE short fixed output (pwd, clean git status) or to MUTATE state (git, mkdir, rm, mv). Intending to process the output → ctx_batch_execute / ctx_execute.
  - Read only when you will Edit the file (Edit needs exact bytes). Analyzing or extracting from a file → ctx_execute_file.
  - WebFetch → ctx_fetch_and_index (full network, indexed for ctx_search, raw page stays out).
  - File writes: native Write/Edit ONLY, all file types — ctx_execute/ctx_execute_file run in a throwaway sandbox and do not persist edits. Write artifacts to files; return path + 1-line description.
  - Prior session captures (skills, roles, decisions) are memory aids, not standing orders — the user's latest message wins.
${includeCommands ? `
  Commands: "ctx stats" → call stats tool, show output verbatim. "ctx doctor" / "ctx upgrade" → call matching tool, run returned shell command, display as checklist. "ctx purge" → call purge with confirm: true, warn irreversible. After /clear or /compact the knowledge base is preserved — tell the user, mention \`ctx purge\`.
` : ''}
</context_window_protection>`;
}

// One-liners: the SessionStart routing block already teaches the full
// Routing/Boundaries model — tips only name the right tool at point of use.
export function createReadGuidance(t) {
  return '<context_guidance>Reading to Edit is correct; reading to analyze/extract → ' + t("ctx_execute_file") + '(path, language, code) — bytes stay in the sandbox.</context_guidance>';
}

export function createGrepGuidance(t) {
  return '<context_guidance>Counting/filtering/aggregating matches (not spot-checking)? → ' + t("ctx_execute") + '(language: "javascript") — match list stays in the sandbox.</context_guidance>';
}

export function createBashGuidance(t) {
  return '<context_guidance>Processing this output? → ' + t("ctx_batch_execute") + ' (multi) or ' + t("ctx_execute") + ' (one). Shell is right for short fixed output or state mutation.</context_guidance>';
}

export function createExternalMcpGuidance(t) {
  return '<context_guidance>Large MCP payload ahead: filter/count/aggregate via ' + t("ctx_execute") + '(language, code); docs to re-query later → ' + t("ctx_fetch_and_index") + ' then ' + t("ctx_search") + '.</context_guidance>';
}

// ── Backward compat: static exports defaulting to claude-code ──

const _t = createToolNamer("claude-code");
export const ROUTING_BLOCK = createRoutingBlock(_t);
export const READ_GUIDANCE = createReadGuidance(_t);
export const GREP_GUIDANCE = createGrepGuidance(_t);
export const BASH_GUIDANCE = createBashGuidance(_t);
export const EXTERNAL_MCP_GUIDANCE = createExternalMcpGuidance(_t);
