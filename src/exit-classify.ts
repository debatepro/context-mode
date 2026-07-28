/**
 * Classify non-zero exit codes for ctx_execute / ctx_execute_file.
 *
 * Shell commands like `grep` exit 1 for "no matches" — not a real error.
 * We treat exit code 1 as a soft failure when:
 *   - language is "shell"
 *   - exit code is exactly 1
 *   - stdout has non-whitespace content
 */
export interface ExitClassification {
  isError: boolean;
  output: string;
}

export function classifyNonZeroExit(params: {
  language: string;
  exitCode: number;
  stdout: string;
  stderr: string;
}): ExitClassification {
  const { language, exitCode, stdout, stderr } = params;
  const isSoftFail =
    language === "shell" &&
    exitCode === 1 &&
    stdout.trim().length > 0;

  return {
    isError: !isSoftFail,
    output: isSoftFail
      ? appendStderr(stdout, stderr)
      : `Exit code: ${exitCode}\n\nstdout:\n${stdout}\n\nstderr:\n${stderr}`,
  };
}

/**
 * Merge a run's stderr into the text the caller sees.
 *
 * Both the soft-fail branch above and ctx_execute's exit-0 path used to return
 * stdout alone, so a command that failed inside an otherwise-succeeding script
 * vanished without a trace — the caller read an empty result as a real answer.
 * Kept as a labeled trailing section (rather than interleaved) so output that
 * downstream code parses stays parseable, and so scripts that write ordinary
 * progress chatter to stderr don't corrupt their own stdout.
 */
export function appendStderr(stdout: string, stderr: string): string {
  if (!stderr.trim()) return stdout;
  const section = `stderr:\n${stderr}`;
  if (!stdout) return section;
  return `${stdout}${stdout.endsWith("\n") ? "" : "\n"}\n${section}`;
}
