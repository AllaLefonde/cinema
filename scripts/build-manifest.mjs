import { readdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import path from "node:path";
import { FILM_META } from "./film-meta.mjs";
import { QUOTE_TRANSLATIONS } from "./quote-translations.mjs";
import { CLAUDE_TRANSLATIONS } from "./claude-translations.mjs";

const root = process.cwd();
const IGNORE = new Set([".git", ".github", ".idea", "node_modules", "scripts"]);

function isImage(name) {
  return /\.(jpe?g|png|gif|webp)$/i.test(name);
}

// Parses "Author: quote" lines from a folder's text.txt into
// { "Author": { ru: "quote", en: "translation", enBy: "claude" } }, skipping
// authors left blank (no quote chosen yet for that photo). "en" preferentially
// comes from a verified published translation in quote-translations.mjs; if
// none exists, falls back to Claude's own translation in
// claude-translations.mjs (marked with enBy: "claude" so the UI can attribute
// it). If neither exists, "en" is omitted and the UI shows the Russian text.
function readWords(dir) {
  const file = path.join(dir, "text.txt");
  if (!existsSync(file)) return undefined;

  const words = {};
  for (const line of readFileSync(file, "utf8").split(/\r?\n/)) {
    const match = line.match(/^([^:]+):\s*(.*)$/);
    if (!match) continue;
    const [, author, quote] = match;
    const ru = quote.trim();
    if (!ru) continue;
    const verified = QUOTE_TRANSLATIONS[ru];
    const claude = CLAUDE_TRANSLATIONS[ru];
    if (verified) words[author.trim()] = { ru, en: verified };
    else if (claude) words[author.trim()] = { ru, en: claude, enBy: "claude" };
    else words[author.trim()] = { ru };
  }
  return Object.keys(words).length ? words : undefined;
}

const folderNames = readdirSync(root, { withFileTypes: true })
  .filter((e) => e.isDirectory() && !IGNORE.has(e.name) && !e.name.startsWith("."))
  .map((e) => e.name)
  .filter((name) => /^\d+$/.test(name))
  .sort((a, b) => Number(a) - Number(b));

const folders = [];

for (const folder of folderNames) {
  const dir = path.join(root, folder);
  const files = readdirSync(dir).filter(isImage);
  const poster = files.find((f) => /^\d_/.test(f));
  if (!poster) continue;
  const second = files.find((f) => f !== poster);
  if (!second) continue;

  const name = poster
    .replace(/^\d_/, "")
    .replace(/\.[^.]+$/, "")
    .replace(/_/g, " ")
    .trim();

  const words = readWords(dir);

  folders.push({ folder, name, poster, second, words });
}

const byName = new Map();
for (const f of folders) {
  if (!byName.has(f.name)) byName.set(f.name, []);
  byName.get(f.name).push(f);
}

const groups = [...byName.entries()]
  .map(([name, items]) => ({
    name,
    ...(FILM_META[name] ?? {}),
    folders: items
      .sort((a, b) => Number(a.folder) - Number(b.folder))
      .map(({ folder, poster, second, words }) => ({
        folder,
        poster,
        second,
        ...(words ? { words } : {}),
      })),
  }))
  .sort((a, b) => a.name.localeCompare(b.name, "ru"));

const output = `window.FILMS = ${JSON.stringify({ groups }, null, 2)};\n`;
writeFileSync(path.join(root, "films-data.js"), output, "utf8");
console.log(`films-data.js written: ${groups.length} films, ${folders.length} folders`);
