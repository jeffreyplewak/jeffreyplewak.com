(() => {
  "use strict";

  const THEME_KEY = "jp_theme"; // "light" | "dark" | null

  function getSystemTheme() {
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches
      ? "light"
      : "dark";
  }

  function getSavedTheme() {
    try {
      const v = localStorage.getItem(THEME_KEY);
      if (v === "light" || v === "dark") return v;
    } catch (_) {}
    return null;
  }

  function setTheme(theme, { persist = true } = {}) {
    const root = document.documentElement;

    // remove explicit theme => let CSS media query drive it
    if (!theme) {
      root.removeAttribute("data-theme");
      try {
        if (persist) localStorage.removeItem(THEME_KEY);
      } catch (_) {}
      syncToggleUI(null);
      return;
    }

    root.setAttribute("data-theme", theme);
    try {
      if (persist) localStorage.setItem(THEME_KEY, theme);
    } catch (_) {}

    syncToggleUI(theme);
  }

function syncToggleUI(theme) {
  const btn = document.getElementById("themeToggle");
  if (!btn) return;

  const effective = theme || getSystemTheme();
  const isLight = effective === "light";

  // aria-pressed=true means light mode is ON
  btn.setAttribute("aria-pressed", String(isLight));
  btn.setAttribute("data-theme-state", isLight ? "light" : "dark");

  // Icon represents the ACTION (what you'll switch to)
  // If currently light -> show moon (switch to dark)
  // If currently dark  -> show sun  (switch to light)
  const icon = btn.querySelector("[data-icon]");
  const label = btn.querySelector("[data-label]");

  const nextTheme = isLight ? "dark" : "light";

  if (icon) icon.textContent = isLight ? "☾" : "☀︎";
  if (label) label.textContent = nextTheme === "light" ? "Light" : "Dark";

  btn.setAttribute(
    "aria-label",
    isLight ? "Switch to dark mode" : "Switch to light mode"
  );
  btn.setAttribute("title", isLight ? "Switch to dark mode" : "Switch to light mode");
}
  function initTheme() {
    const saved = getSavedTheme();
    if (saved) {
      setTheme(saved, { persist: false });
    } else {
      // no explicit theme => follow system
      setTheme(null, { persist: false });
    }

    // If user never chose a theme, keep UI synced when system changes
    if (window.matchMedia) {
      const mq = window.matchMedia("(prefers-color-scheme: light)");
      const handler = () => {
        if (!getSavedTheme()) syncToggleUI(null);
      };
      if (mq.addEventListener) mq.addEventListener("change", handler);
      else if (mq.addListener) mq.addListener(handler);
    }
  }

  function initThemeToggle() {
    const btn = document.getElementById("themeToggle");
    if (!btn) return;

    btn.addEventListener("click", () => {
      const root = document.documentElement;
      const current = root.getAttribute("data-theme");
      const effective = current || getSystemTheme();

      const next = effective === "light" ? "dark" : "light";
      setTheme(next);
    });
  }

  function initYear() {
    const y = document.getElementById("year");
    if (!y) return;
    y.textContent = String(new Date().getFullYear());
  }

  // Boot
  document.addEventListener("DOMContentLoaded", () => {
    initTheme();
    initThemeToggle();
    initYear();
  });
})();