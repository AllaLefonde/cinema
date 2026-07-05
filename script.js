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

function renderList() {
  const items = window.FILMS.groups
    .map((g) => {
      const first = g.folders[0].folder;
      return `<li><a href="#/${first}"><span>${escapeHtml(g.name)}</span></a></li>`;
    })
    .join("\n");
  return `<ul class="index-list">${items}</ul>`;
}

function renderFilm(folder, found) {
  const { group, idx } = found;
  const gn = group.folders.length;
  const current = group.folders[idx];
  const nameHtml = escapeHtml(group.name);

  const prevFolder = idx > 0 ? group.folders[idx - 1].folder : null;
  const nextFolder = idx < gn - 1 ? group.folders[idx + 1].folder : null;

  const prevLink = prevFolder
    ? `<a href="#/${prevFolder}">&larr;</a>`
    : `<span class="disabled">&larr;</span>`;
  const nextLink = nextFolder
    ? `<a href="#/${nextFolder}">&rarr;</a>`
    : `<span class="disabled">&rarr;</span>`;

  const posterSrc = `${current.folder}/${encodeURI(current.poster)}`;
  const secondSrc = `${current.folder}/${encodeURI(current.second)}`;

  return `
<h1 class="film-title">${nameHtml}</h1>
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

function render() {
  const app = document.getElementById("app");
  const folder = location.hash.replace(/^#\/?/, "");

  if (!folder) {
    document.title = "Кино от Димы Конрадта";
    app.innerHTML = renderList();
    return;
  }

  const found = findByFolder(folder);
  if (!found) {
    location.hash = "#/";
    return;
  }

  document.title = `${found.group.name} — Кино от Димы Конрадта`;
  app.innerHTML = renderFilm(folder, found);
}

window.addEventListener("hashchange", render);
window.addEventListener("DOMContentLoaded", render);
