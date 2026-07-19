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
// { "Author": { ru, en, translator } | { ru, en, enBy: "claude" } | { ru } },
// skipping authors left blank (no quote chosen yet for that photo). "en"
// preferentially comes from a verified published translation in
// quote-translations.mjs (credited via "translator", shown as a small person
// icon in the UI); if none exists, falls back to Claude's own translation in
// claude-translations.mjs (marked with enBy: "claude", shown as a small
// Claude icon). If neither exists, "en" is omitted and the UI shows Russian.
function readWords(dir) {
  const file = path.join(dir, "text.txt");
  if (!existsSync(file)) return undefined;

  const words = {};
  for (const line of readFileSync(file, "utf8").split(/\r?\n/)) {
    const match = line.match(/^([^:]+):\s*(.*)$/);
    if (!match) continue;
    const [, author, quote] = match;
    if (author.trim().toLowerCase() === "order") continue;
    const ru = quote.trim();
    if (!ru) continue;
    const verified = QUOTE_TRANSLATIONS[ru];
    const claude = CLAUDE_TRANSLATIONS[ru];
    if (verified) words[author.trim()] = { ru, en: verified.en, translator: verified.translator };
    else if (claude) words[author.trim()] = { ru, en: claude, enBy: "claude" };
    else words[author.trim()] = { ru };
  }
  return Object.keys(words).length ? words : undefined;
}

// Reads the "order: N" line from a folder's text.txt, if any. N is the
// photo's position within the user's full (larger) set of photos for that
// film, so folders sharing a film sort by it instead of by folder number.
// Folders with no order yet fall back to sorting by folder number, after any
// folders that do have an explicit order.
function readOrder(dir) {
  const file = path.join(dir, "text.txt");
  if (!existsSync(file)) return undefined;
  const match = readFileSync(file, "utf8").match(/^order:\s*(.*)$/im);
  if (!match) return undefined;
  const n = Number(match[1].trim());
  return match[1].trim() && Number.isFinite(n) ? n : undefined;
}

// Reads the "change: true" line from a folder's text.txt, if any. When set,
// the two commentators' quotes swap positions (which one sits above the
// second photo vs below the poster) relative to the default layout.
function readChange(dir) {
  const file = path.join(dir, "text.txt");
  if (!existsSync(file)) return undefined;
  return /^change:\s*true\s*$/im.test(readFileSync(file, "utf8")) || undefined;
}

function sortKey(f) {
  return f.order ?? Number(f.folder) + 100000;
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
  const order = readOrder(dir);
  const change = readChange(dir);

  folders.push({ folder, name, poster, second, words, order, change });
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
      .sort((a, b) => sortKey(a) - sortKey(b))
      .map(({ folder, poster, second, words, change }) => ({
        folder,
        poster,
        second,
        ...(words ? { words } : {}),
        ...(change ? { change } : {}),
      })),
  }))
  .sort((a, b) => a.name.localeCompare(b.name, "ru"));

const output = `window.FILMS = ${JSON.stringify({ groups }, null, 2)};\n`;
writeFileSync(path.join(root, "films-data.js"), output, "utf8");
console.log(`films-data.js written: ${groups.length} films, ${folders.length} folders`);
