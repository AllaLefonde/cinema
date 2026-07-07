import { readdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { FILM_META } from "./film-meta.mjs";

const root = process.cwd();
const IGNORE = new Set([".git", ".github", ".idea", "node_modules", "scripts"]);

function isImage(name) {
  return /\.(jpe?g|png|gif|webp)$/i.test(name);
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

  folders.push({ folder, name, poster, second });
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
      .map(({ folder, poster, second }) => ({ folder, poster, second })),
  }))
  .sort((a, b) => a.name.localeCompare(b.name, "ru"));

const output = `window.FILMS = ${JSON.stringify({ groups }, null, 2)};\n`;
writeFileSync(path.join(root, "films-data.js"), output, "utf8");
console.log(`films-data.js written: ${groups.length} films, ${folders.length} folders`);
