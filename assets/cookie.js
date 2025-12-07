// assets/cookie.js
// Simple cookie banner controller shared across pages.
// Assumes a banner element with id="cookie-banner" and buttons with ids:
//   cookie-accept, cookie-decline, cookie-close, cookie-preferences (optional).

(function () {
  var COOKIE_NAME = "jp_cookie_pref";
  var COOKIE_MAX_AGE_DAYS = 365;

  function setCookie(name, value, days) {
    try {
      var expires = "";
      if (typeof days === "number") {
        var date = new Date();
        date.setTime(date.getTime() + days * 24 * 60 * 60 * 1000);
        expires = "; expires=" + date.toUTCString();
      }
      // Lax is fine for this use; we are not doing cross-site auth
      document.cookie =
        name +
        "=" +
        encodeURIComponent(value) +
        expires +
        "; path=/; SameSite=Lax";
    } catch (e) {
      // Fail silently; banner will just reappear next visit
    }
  }

  function getCookie(name) {
    if (typeof document === "undefined" || !document.cookie) return null;
    var nameEQ = name + "=";
    var ca = document.cookie.split(";");
    for (var i = 0; i < ca.length; i++) {
      var c = ca[i];
      while (c.charAt(0) === " ") c = c.substring(1, c.length);
      if (c.indexOf(nameEQ) === 0) {
        return decodeURIComponent(c.substring(nameEQ.length, c.length));
      }
    }
    return null;
  }

  function showBannerIfNeeded() {
    var banner = document.getElementById("cookie-banner");
    if (!banner) return;

    var pref = getCookie(COOKIE_NAME);
    if (!pref) {
      banner.hidden = false;
    }
  }

  function hideBanner() {
    var banner = document.getElementById("cookie-banner");
    if (banner) banner.hidden = true;
  }

  function handleAccept() {
    setCookie(COOKIE_NAME, "all", COOKIE_MAX_AGE_DAYS);
    hideBanner();
    // If you later add optional analytics, you can init them here.
  }

  function handleDecline() {
    setCookie(COOKIE_NAME, "necessary", COOKIE_MAX_AGE_DAYS);
    hideBanner();
    // Optional: disable any non-essential scripts if you add them.
  }

  function handleClose() {
    // Close without setting anything; banner may reappear on next visit
    hideBanner();
  }

  function handlePreferences() {
    // For now, just toggle between states in a minimal way.
    // If you add a full preferences UI later, wire it here.
    var current = getCookie(COOKIE_NAME);
    if (current === "necessary") {
      setCookie(COOKIE_NAME, "all", COOKIE_MAX_AGE_DAYS);
    } else if (current === "all") {
      setCookie(COOKIE_NAME, "necessary", COOKIE_MAX_AGE_DAYS);
    }
    hideBanner();
  }

  function attachHandlers() {
    var acceptBtn = document.getElementById("cookie-accept");
    var declineBtn = document.getElementById("cookie-decline");
    var closeBtn = document.getElementById("cookie-close");
    var prefBtn = document.getElementById("cookie-preferences");

    if (acceptBtn) {
      acceptBtn.addEventListener("click", handleAccept);
    }
    if (declineBtn) {
      declineBtn.addEventListener("click", handleDecline);
    }
    if (closeBtn) {
      closeBtn.addEventListener("click", handleClose);
    }
    if (prefBtn) {
      prefBtn.addEventListener("click", handlePreferences);
    }
  }

  if (typeof window !== "undefined") {
    window.addEventListener("load", function () {
      attachHandlers();
      showBannerIfNeeded();
    });
  }
})();