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

function renderFilmListItem(group) {
  const first = group.folders[0].folder;
  const title = escapeHtml(filmTitle(group));
  return `<li><a href="#/${first}" class="film-link" data-preload-folder="${first}"><span>${title}</span></a>${imdbBadge(group.imdbId)}</li>`;
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

  return [...byDirector.values()]
    .sort((a, b) => {
      const an = lang === "en" ? a.director.en : a.director.ru;
      const bn = lang === "en" ? b.director.en : b.director.ru;
      return an.localeCompare(bn, lang === "en" ? "en" : "ru");
    })
    .map(({ director, films }) => {
      const name = escapeHtml(lang === "en" ? director.en : director.ru);
      const items = films.map(renderFilmListItem).join("\n");
      return `
<section class="director-section">
<h2 class="director-heading"><a class="imdb-popup" href="https://www.imdb.com/name/${director.imdbId}/">${name}</a></h2>
<ul class="index-list">${items}</ul>
</section>`;
    })
    .join("\n");
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

  return `
<h1 class="film-title">${nameHtml} ${imdbBadge(group.imdbId)}</h1>
${directorHtml}
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

function updateStaticText() {
  const lang = getLang();
  const siteTitleLink = document.querySelector(".site-title a");
  if (siteTitleLink) siteTitleLink.textContent = I18N[lang].siteTitle;
  document.querySelectorAll(".lang-switch button").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.lang === lang);
  });
}

function render() {
  const app = document.getElementById("app");
  const route = location.hash.replace(/^#\/?/, "");

  updateStaticText();

  if (!route) {
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
  render();
});
