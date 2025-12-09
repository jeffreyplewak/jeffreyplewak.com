// assets/cookie.js
// Minimal cookie banner controller.
// Stores a simple preference and hides the banner across all pages.

(function () {
  var STORAGE_KEY = "jp_cookie_pref"; // "essential" | "all"

  function getPref() {
    try {
      return window.localStorage.getItem(STORAGE_KEY);
    } catch (e) {
      return null;
    }
  }

  function setPref(value) {
    try {
      window.localStorage.setItem(STORAGE_KEY, value);
    } catch (e) {
      // ignore storage errors in strict modes
    }
  }

  function hideBanner(banner) {
    if (banner) {
      banner.classList.remove("is-visible");
    }
  }

  function showBanner(banner) {
    if (banner) {
      banner.classList.add("is-visible");
    }
  }

  function wireBanner() {
    var banner = document.querySelector("[data-cookie-banner]");
    if (!banner) return;

    var acceptBtn = banner.querySelector("[data-cookie-accept]");
    var declineBtn = banner.querySelector("[data-cookie-decline]");

    var pref = getPref();
    if (pref === "essential" || pref === "all") {
      // Preference already set: keep banner hidden.
      hideBanner(banner);
    } else {
      // No preference yet: show banner.
      showBanner(banner);
    }

    if (acceptBtn) {
      acceptBtn.addEventListener("click", function () {
        setPref("all");
        hideBanner(banner);
        // If you later add analytics, init them here.
      });
    }

    if (declineBtn) {
      declineBtn.addEventListener("click", function () {
        setPref("essential");
        hideBanner(banner);
        // If you have optional scripts, ensure they are not loaded.
      });
    }
  }

  if (
    document.readyState === "complete" ||
    document.readyState === "interactive"
  ) {
    wireBanner();
  } else {
    document.addEventListener("DOMContentLoaded", wireBanner);
  }
})();