const I18N = {
  ru: {
    siteTitle: "Кино от Димы Конрадта",
    director: "Режиссёр",
  },
  en: {
    siteTitle: "Cinema by Dima Konradt",
    director: "Director",
  },
};

function getLang() {
  return localStorage.getItem("lang") === "en" ? "en" : "ru";
}

const WORDS_AUTHORS = [
  { value: "", label: "—" },
  { value: "Иосиф Бродский", label: "Бродский" },
  { value: "Агния Барто", label: "Барто" },
];

function getWordsAuthor() {
  const saved = localStorage.getItem("wordsAuthor");
  return WORDS_AUTHORS.some((a) => a.value === saved) ? saved : "";
}

function t(key) {
  return I18N[getLang()][key];
}

function escapeHtml(s) {
  return s.replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[c]);
}

function findByFolder(folder) {
  for (const group of window.FILMS.groups) {
    const idx = group.folders.findIndex((f) => f.folder === folder);
    if (idx !== -1) return { group, idx };
  }
  return null;
}

function filmTitle(group) {
  const lang = getLang();
  return lang === "en" && group.titleEn ? group.titleEn : group.name;
}

function directorName(group) {
  if (!group.director) return null;
  return getLang() === "en" ? group.director.en : group.director.ru;
}

function imdbBadge(imdbId) {
  if (!imdbId) return "";
  return `<a class="imdb-badge imdb-popup" href="https://www.imdb.com/title/${imdbId}/">IMDb</a>`;
}

function directorLink(group) {
  if (!group.director) return "";
  const name = escapeHtml(directorName(group));
  return `<a class="director-link imdb-popup" href="https://www.imdb.com/name/${group.director.imdbId}/">${name}</a>`;
}

function openImdbPopup(url) {
  window.open(url, "imdb_popup", "width=1000,height=800,noopener,noreferrer");
}

function preloadFolder(folder) {
  const found = findByFolder(folder);
  if (!found) return;
  const entry = found.group.folders[found.idx];
  [entry.poster, entry.second].forEach((name) => {
    const img = new Image();
    img.src = `${entry.folder}/${encodeURI(name)}`;
  });
}

function attachPreloadHandlers() {
  document.querySelectorAll("#app [data-preload-folder]").forEach((el) => {
    el.addEventListener(
      "mouseenter",
      () => preloadFolder(el.dataset.preloadFolder),
      { once: true }
    );
  });
}

function attachImdbPopupHandlers() {
  document.querySelectorAll("#app .imdb-popup").forEach((el) => {
    el.addEventListener("click", (e) => {
      e.preventDefault();
      openImdbPopup(el.href);
    });
  });
}

function initWordsSelect() {
  const select = document.getElementById("words-select");
  if (!select) return;
  select.addEventListener("change", () => {
    localStorage.setItem("wordsAuthor", select.value);
    render();
  });
}

function renderList() {
  const lang = getLang();
  const byDirector = new Map();
  for (const group of window.FILMS.groups) {
    if (!group.director) continue;
    const key = group.director.imdbId;
    if (!byDirector.has(key)) byDirector.set(key, { director: group.director, films: [] });
    byDirector.get(key).films.push(group);
  }

  const directors = [...byDirector.values()].sort((a, b) => {
    const an = lang === "en" ? a.director.en : a.director.ru;
    const bn = lang === "en" ? b.director.en : b.director.ru;
    return an.localeCompare(bn, lang === "en" ? "en" : "ru");
  });

  const cells = [];
  directors.forEach(({ director, films }, di) => {
    const dirName = escapeHtml(lang === "en" ? director.en : director.ru);
    films.forEach((group, fi) => {
      const first = group.folders[0].folder;
      const title = escapeHtml(filmTitle(group));
      const startClass = fi === 0 && di > 0 ? " director-start" : "";

      const dirCell = fi === 0
        ? `<a class="director-cell imdb-popup${startClass}" href="https://www.imdb.com/name/${director.imdbId}/">${dirName}</a>`
        : `<span class="director-cell${startClass}"></span>`;
      const filmCell = `<a href="#/${first}" class="film-cell${startClass}" data-preload-folder="${first}">${title}</a>`;
      const badgeCell = group.imdbId
        ? `<a class="badge-cell imdb-badge imdb-popup${startClass}" href="https://www.imdb.com/title/${group.imdbId}/">IMDb</a>`
        : `<span class="badge-cell${startClass}"></span>`;

      cells.push(dirCell, filmCell, badgeCell);
    });
  });

  return `<div class="films-grid">${cells.join("")}</div>`;
}

function renderFilm(folder, found) {
  const { group, idx } = found;
  const gn = group.folders.length;
  const current = group.folders[idx];
  const nameHtml = escapeHtml(filmTitle(group));

  const prevFolder = idx > 0 ? group.folders[idx - 1].folder : null;
  const nextFolder = idx < gn - 1 ? group.folders[idx + 1].folder : null;

  const prevLink = prevFolder
    ? `<a href="#/${prevFolder}" data-preload-folder="${prevFolder}">&larr;</a>`
    : `<span class="disabled">&larr;</span>`;
  const nextLink = nextFolder
    ? `<a href="#/${nextFolder}" data-preload-folder="${nextFolder}">&rarr;</a>`
    : `<span class="disabled">&rarr;</span>`;

  const posterSrc = `${current.folder}/${encodeURI(current.poster)}`;
  const secondSrc = `${current.folder}/${encodeURI(current.second)}`;

  const directorHtml = group.director
    ? `<p class="director-line">${t("director")}: ${directorLink(group)}</p>`
    : "";

  const wordsAuthor = getWordsAuthor();
  const entry = wordsAuthor && current.words ? current.words[wordsAuthor] : null;
  const showingEn = getLang() === "en" && !!entry?.en;
  const quote = entry ? (showingEn ? entry.en : entry.ru) : null;
  const claudeMark =
    showingEn && entry.enBy === "claude"
      ? `<sup class="claude-mark" title="Translation: Claude (unofficial)">✳</sup>`
      : "";
  const translatorMark =
    showingEn && entry.translator
      ? `<sup class="translator-mark" title="Translation: ${escapeHtml(entry.translator)}">&#128100;</sup>`
      : "";
  const quoteHtml = quote
    ? `<p class="words-quote">${escapeHtml(quote)}${claudeMark}${translatorMark}</p>`
    : "";

  const metaRowHtml =
    directorHtml || quoteHtml
      ? `<div class="meta-row">${directorHtml}${quoteHtml}</div>`
      : "";

  return `
<div class="title-row">
<h1 class="film-title">${nameHtml} ${imdbBadge(group.imdbId)}</h1>
</div>
${metaRowHtml}
<div class="content-wrap">
<div class="gallery">
<img src="${posterSrc}" alt="${nameHtml}">
<img src="${secondSrc}" alt="${nameHtml}">
</div>
<div class="nav-row">
<div class="nav-arrows">
${prevLink}
<a href="#/">&uarr;</a>
${nextLink}
</div>
<span class="counter">${idx + 1} / ${gn}</span>
</div>
</div>`;
}

function updateStaticText(showWordsSelect) {
  const lang = getLang();
  const siteTitleLink = document.querySelector(".site-title a");
  if (siteTitleLink) siteTitleLink.textContent = I18N[lang].siteTitle;
  document.querySelectorAll(".lang-switch button").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.lang === lang);
  });

  const wordsSwitch = document.getElementById("words-switch");
  if (wordsSwitch) wordsSwitch.style.display = showWordsSelect ? "flex" : "none";
  const wordsSelect = document.getElementById("words-select");
  if (wordsSelect) wordsSelect.value = getWordsAuthor();
}

function render() {
  const app = document.getElementById("app");
  const route = location.hash.replace(/^#\/?/, "");

  if (!route) {
    updateStaticText(false);
    document.title = I18N[getLang()].siteTitle;
    app.innerHTML = renderList();
    attachPreloadHandlers();
    attachImdbPopupHandlers();
    return;
  }

  const found = findByFolder(route);
  if (!found) {
    location.hash = "#/";
    return;
  }

  const currentFolder = found.group.folders[found.idx];
  const hasWords = !!(currentFolder.words && Object.keys(currentFolder.words).length);
  updateStaticText(hasWords);
  document.title = `${filmTitle(found.group)} — ${I18N[getLang()].siteTitle}`;
  app.innerHTML = renderFilm(route, found);
  attachPreloadHandlers();
  attachImdbPopupHandlers();
}

function initLangSwitch() {
  document.querySelectorAll(".lang-switch button").forEach((btn) => {
    btn.addEventListener("click", () => {
      localStorage.setItem("lang", btn.dataset.lang);
      render();
    });
  });
}

window.addEventListener("hashchange", render);
window.addEventListener("DOMContentLoaded", () => {
  initLangSwitch();
  initWordsSelect();
  render();
});
