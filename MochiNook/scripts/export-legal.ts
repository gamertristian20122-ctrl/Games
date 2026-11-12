// Writes docs/privacy-policy.html and docs/terms.html from src/data/legal.ts.
// Host these anywhere public (e.g. GitHub Pages) and paste the privacy URL into Play Console.
import { writeFileSync } from 'node:fs';
import { PRIVACY_POLICY, TERMS_OF_USE, type LegalDoc } from '../src/data/legal';

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function page(doc: LegalDoc): string {
  const body = doc.sections
    .map((s) => `<h2>${esc(s.heading)}</h2>\n${s.paragraphs.map((p) => `<p>${esc(p)}</p>`).join('\n')}`)
    .join('\n');
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(doc.title)}</title>
<style>
  :root { color-scheme: light dark; --bg: #FBF5EC; --ink: #3E3833; --soft: #6B625A; }
  @media (prefers-color-scheme: dark) { :root { --bg: #24201D; --ink: #F4EDE4; --soft: #CBC1B6; } }
  body { margin: 0; background: var(--bg); color: var(--ink); font: 17px/1.6 system-ui, sans-serif; }
  main { max-width: 680px; margin: 0 auto; padding: 32px 16px 64px; }
  h1 { font-size: 28px; line-height: 1.25; margin: 0 0 4px; }
  h2 { font-size: 19px; margin: 32px 0 8px; }
  p { margin: 0 0 12px; color: var(--soft); }
  .updated { font-size: 14px; }
  .intro { color: var(--ink); }
</style>
</head>
<body><main>
<h1>${esc(doc.title)}</h1>
<p class="updated">Last updated ${esc(doc.updated)}</p>
<p class="intro">${esc(doc.intro)}</p>
${body}
</main></body>
</html>
`;
}

writeFileSync(new URL('../docs/privacy-policy.html', import.meta.url), page(PRIVACY_POLICY));
writeFileSync(new URL('../docs/terms.html', import.meta.url), page(TERMS_OF_USE));
console.log('Wrote docs/privacy-policy.html and docs/terms.html');
