/** Pulls 4–6 clean, de-duplicated steps out of a model reply (numbered or bulleted list). */
export function parseSteps(reply: string): string[] {
  const lines = reply
    .split(/\r?\n/)
    .map((l) => l.replace(/^\s*(?:\d+[.)]|[-*•])\s*/, '').replace(/\*\*/g, '').trim())
    .filter((l) => l.length > 3 && l.length < 160 && !/^(here|sure|steps?:)/i.test(l));
  return Array.from(new Set(lines)).slice(0, 6);
}
