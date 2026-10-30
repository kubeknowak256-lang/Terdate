const REPO_OWNER = "kubeknowak256-lang";
const REPO_NAME = "Terdate";
const RELEASES_URL = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases`;

const TEXT_FILES = {
  en: {
    short: "./web/short-info.txt",
    info: "./web/info.txt",
    plans: "./web/plans.txt",
    systems: "./web/systems.txt"
  },
  pl: {
    short: "./web/short-info_PL.txt",
    info: "./web/info_PL.txt",
    plans: "./web/plans_PL.txt",
    systems: "./web/systems_PL.txt"
  }
};

const translations = {
  en: {
    releaseLabel: "Latest release",
    viewRelease: "View release",
    downloadAsset: "Download asset",
    allVersions: "All versions",
    noRelease: "No release information is available right now.",
    home: "Home",
    download: "Download",
    features: "Features",
    plans: "Future plans",
    system: "System & kernel",
    learnMore: "Learn more",
    open: "Open"
  },
  pl: {
    releaseLabel: "Najnowsza wersja",
    viewRelease: "Zobacz wydanie",
    downloadAsset: "Pobierz plik",
    allVersions: "Wszystkie wersje",
    noRelease: "Brak informacji o wydaniach w tej chwili.",
    home: "Strona główna",
    download: "Pobierz",
    features: "Funkcje",
    plans: "Plany na przyszłość",
    system: "O systemie i jądrze",
    learnMore: "Dowiedz się więcej",
    open: "Otwórz"
  }
};

const state = {
  language: "en",
  activeSection: "home"
};

const navButtons = [...document.querySelectorAll(".nav-btn")];
const panels = {
  home: document.getElementById("home"),
  download: document.getElementById("download"),
  features: document.getElementById("features"),
  plans: document.getElementById("plans"),
  system: document.getElementById("system")
};

const shortSummary = document.getElementById("shortSummary");
const plansContent = document.getElementById("plansContent");
const systemInfo = document.getElementById("systemInfo");
const latestRelease = document.getElementById("latestRelease");
const releaseList = document.getElementById("releaseList");
const langToggle = document.getElementById("langToggle");

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function parseMarkdown(md) {
  const text = md || "";
  const blocks = text.split(/\n\n+/).filter(Boolean);

  return blocks
    .map((block) => {
      const trimmed = block.trim();
      if (!trimmed) return "";

      if (/^#{1,6}\s/.test(trimmed)) {
        const level = trimmed.match(/^#+/)?.[0].length || 1;
        const content = trimmed.replace(/^#+\s*/, "");
        return `<h${level}>${escapeHtml(content)}</h${level}>`;
      }

      if (/^-\s+/.test(trimmed)) {
        const items = trimmed
          .split(/\n/)
          .filter((line) => line.trim().startsWith("- "))
          .map((line) => `<li>${escapeHtml(line.replace(/^-\s*/, ""))}</li>`)
          .join("");
        return `<ul>${items}</ul>`;
      }

      if (/^\d+\.\s+/.test(trimmed)) {
        const items = trimmed
          .split(/\n/)
          .filter((line) => /^\d+\.\s+/.test(line))
          .map((line) => `<li>${escapeHtml(line.replace(/^\d+\.\s*/, ""))}</li>`)
          .join("");
        return `<ol>${items}</ol>`;
      }

      return `<p>${escapeHtml(trimmed).replace(/\n/g, "<br>")}</p>`;
    })
    .join("");
}

function getFallbackText(lang, key) {
  const fallback = {
    en: {
      short: "<p>Terdate is a lightweight retro operating system centered on a custom 32-bit kernel and a minimal batch-style runtime.</p>",
      info: "<p>Detailed system information is stored in the repository and will be displayed when the file is available.</p>",
      plans: "<p>Roadmap data is maintained in the project and will be loaded automatically when the content files are present.</p>"
    },
    pl: {
      short: "<p>Terdate to lekki retro system operacyjny oparty na własnym 32-bitowym jądrze i prostym środowisku skryptów wsadowych.</p>",
      info: "<p>Szczegółowe informacje o systemie są przechowywane w repozytorium i zostaną załadowane, gdy pliki będą dostępne.</p>",
      plans: "<p>Plan rozwoju jest utrzymywany w projekcie i zostanie załadowany automatycznie po pojawieniu się plików z treścią.</p>"
    }
  };

  return fallback[lang]?.[key] || fallback.en[key];
}

async function fetchText(url) {
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) throw new Error(`Failed to load ${url}`);
  return response.text();
}

async function loadTextFiles(lang = state.language) {
  const currentFiles = TEXT_FILES[lang] || TEXT_FILES.en;

  try {
    const [shortText, infoText, plansText] = await Promise.all([
      fetchText(currentFiles.short),
      fetchText(currentFiles.info),
      fetchText(currentFiles.plans)
    ]);

    shortSummary.innerHTML = parseMarkdown(shortText);
    systemInfo.innerHTML = parseMarkdown(infoText);
    plansContent.innerHTML = parseMarkdown(plansText);
  } catch (error) {
    shortSummary.innerHTML = getFallbackText(lang, "short");
    systemInfo.innerHTML = getFallbackText(lang, "info");
    plansContent.innerHTML = getFallbackText(lang, "plans");
  }
}

function updateNavLabels() {
  navButtons.forEach((button) => {
    const target = button.dataset.target;
    button.textContent = translations[state.language][target] || target;
  });
}

function updateLanguageLabels() {
  const isEn = state.language === "en";

  document.documentElement.lang = state.language;
  langToggle.textContent = isEn ? "🇺🇸" : "🇵🇱";
  langToggle.setAttribute(
    "aria-label",
    isEn ? "Switch language to Polish" : "Przełącz język na angielski"
  );

  updateNavLabels();

  const headings = document.querySelectorAll("h2");
  headings.forEach((el) => {
    const text = el.textContent.trim().toLowerCase();
    if (text === "download") el.textContent = isEn ? "Download" : "Pobierz";
    if (text === "features") el.textContent = isEn ? "Features" : "Funkcje";
    if (text === "future plans") el.textContent = isEn ? "Future plans" : "Plany na przyszłość";
    if (text === "system and kernel") el.textContent = isEn ? "System and kernel" : "O systemie i jądrze";
  });

  const allVersionsHeading = document.querySelector(".all-releases h3");
  if (allVersionsHeading) {
    allVersionsHeading.textContent = isEn ? "All versions" : "Wszystkie wersje";
  }

  const learnMore = document.querySelector(".btn-secondary");
  if (learnMore) {
    learnMore.textContent = isEn ? translations.en.learnMore : translations.pl.learnMore;
  }
}

function setActiveSection(target) {
  state.activeSection = target;

  navButtons.forEach((button) => {
    button.classList.toggle("active", button.dataset.target === target);
  });

  Object.entries(panels).forEach(([key, panel]) => {
    panel.classList.toggle("active", key === target);
  });
}

function renderLatestRelease(release) {
  if (!release) {
    latestRelease.innerHTML = `<div class="badge">${translations[state.language].noRelease}</div>`;
    return;
  }

  const tag = release.tag_name || release.name || "Release";
  const body = (release.body || "No description provided.").replace(/\r/g, "").trim();
  const asset = release.assets && release.assets.length ? release.assets[0] : null;

  latestRelease.innerHTML = `
    <div class="badge">${translations[state.language].releaseLabel}</div>
    <h3>${escapeHtml(release.name || tag)}</h3>
    <p>${escapeHtml(body)}</p>
    <div class="release-actions">
      <a href="${release.html_url}" class="btn btn-primary" target="_blank" rel="noreferrer">
        ${translations[state.language].viewRelease}
      </a>
      ${
        asset
          ? `<a href="${asset.browser_download_url}" class="btn btn-secondary" target="_blank" rel="noreferrer">
              ${translations[state.language].downloadAsset}
            </a>`
          : ""
      }
    </div>
  `;
}

function renderReleaseList(releases) {
  releaseList.innerHTML = "";

  if (!releases || !releases.length) {
    releaseList.innerHTML = `<li>${translations[state.language].noRelease}</li>`;
    return;
  }

  releases.forEach((release) => {
    const item = document.createElement("li");
    const tag = release.tag_name || release.name || "Release";

    item.innerHTML = `
      <span>${escapeHtml(tag)}</span>
      <a href="${release.html_url}" target="_blank" rel="noreferrer">${translations[state.language].open}</a>
    `;
    releaseList.appendChild(item);
  });
}

async function loadReleasesFromGithub() {
  try {
    const response = await fetch(RELEASES_URL, {
      headers: { Accept: "application/vnd.github+json" },
      cache: "no-store"
    });

    if (!response.ok) {
      throw new Error("GitHub releases request failed");
    }

    const releases = await response.json();
    const valid = Array.isArray(releases) ? releases.filter(Boolean) : [];

    if (!valid.length) return false;

    renderLatestRelease(valid[0]);
    renderReleaseList(valid);
    return true;
  } catch (error) {
    return false;
  }
}

function parseSystemsFallback(text) {
  const lines = text
    .split(/\n+/)
    .map((line) => line.trim())
    .filter(Boolean);

  return lines
    .map((line) => {
      const match = line.match(/^\s*(\d+)[.)-]?\s*(.+?)\s*$/);
      if (!match) return null;

      const order = Number(match[1]);
      const name = match[2].trim();

      return {
        order,
        name,
        url: `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/tag/${encodeURIComponent(name)}`
      };
    })
    .filter(Boolean)
    .sort((a, b) => a.order - b.order);
}

async function loadSystemFallback(lang = state.language) {
  const currentFiles = TEXT_FILES[lang] || TEXT_FILES.en;

  try {
    const text = await fetchText(currentFiles.systems);
    const entries = parseSystemsFallback(text);

    if (!entries.length) {
      return false;
    }

    const latest = entries[0];

    renderLatestRelease({
      name: latest.name,
      tag_name: latest.name,
      html_url: latest.url,
      body: "Latest system build defined in the fallback version list.",
      assets: []
    });

    releaseList.innerHTML = "";
    entries.forEach((entry) => {
      const li = document.createElement("li");
      li.innerHTML = `
        <span>${escapeHtml(entry.name)}</span>
        <a href="${entry.url}" target="_blank" rel="noreferrer">${translations[state.language].open}</a>
      `;
      releaseList.appendChild(li);
    });

    return true;
  } catch (error) {
    return false;
  }
}

async function loadReleaseData(lang = state.language) {
  const githubWorked = await loadReleasesFromGithub();
  if (githubWorked) return;

  const fallbackWorked = await loadSystemFallback(lang);
  if (!fallbackWorked) {
    latestRelease.innerHTML = `<div class="badge">${translations[state.language].noRelease}</div>`;
    releaseList.innerHTML = `<li>${translations[state.language].noRelease}</li>`;
  }
}

navButtons.forEach((button) => {
  button.addEventListener("click", () => {
    setActiveSection(button.dataset.target);
  });
});

langToggle.addEventListener("click", async () => {
  state.language = state.language === "en" ? "pl" : "en";
  updateLanguageLabels();
  await loadTextFiles(state.language);
  await loadReleaseData(state.language);
});

(async function init() {
  setActiveSection("home");
  updateLanguageLabels();
  await loadTextFiles(state.language);
  await loadReleaseData(state.language);
})();
