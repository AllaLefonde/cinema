// One-off manual utility (not part of the GitHub Actions build pipeline).
// Renders a folder's film page in a real headless browser, hides the topbar
// and the fixed nav-row (arrows + counter), and saves a screenshot of just
// the poster/second-image/caption area into that folder.
//
// Setup (once):
//   npm install --no-save playwright
//   npx playwright install chromium
//
// Usage:
//   node scripts/screenshot-folder.mjs <folder-number>
// Example:
//   node scripts/screenshot-folder.mjs 1

import { chromium } from "playwright";
import { readdirSync, readFileSync, existsSync } from "node:fs";
import path from "node:path";

const folder = process.argv[2];
if (!folder) {
  console.error("Usage: node scripts/screenshot-folder.mjs <folder-number>");
  process.exit(1);
}

const root = process.cwd();
const dir = path.join(root, folder);
if (!existsSync(dir)) {
  console.error(`Folder not found: ${dir}`);
  process.exit(1);
}

const files = readdirSync(dir).filter((f) => /\.(jpe?g|png|gif|webp)$/i.test(f));
const poster = files.find((f) => /^\d_/.test(f));
if (!poster) {
  console.error(`No poster (starting with a digit + "_") found in folder ${folder}`);
  process.exit(1);
}

let order = "";
const textPath = path.join(dir, "text.txt");
if (existsSync(textPath)) {
  const match = readFileSync(textPath, "utf8").match(/^order:\s*(.*)$/im);
  if (match) order = match[1].trim();
}

const ext = path.extname(poster);
const base = poster.slice(0, -ext.length);
const outName = order ? `${base}_${order}${ext}` : `${base}${ext}`;
const outPath = path.join(dir, outName);

const indexUrl = "file://" + path.join(root, "index.html").replace(/\\/g, "/") + `#/${folder}`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 1000 } });
await page.goto(indexUrl);
await page.waitForSelector(".content-wrap");
await page.evaluate(() => {
  document.querySelectorAll(".topbar, .nav-row").forEach((el) => {
    el.style.display = "none";
  });
});
await page.waitForTimeout(300);

const contentWrap = page.locator(".content-wrap");
await contentWrap.screenshot({ path: outPath });

await browser.close();
console.log(`Saved: ${outPath}`);
