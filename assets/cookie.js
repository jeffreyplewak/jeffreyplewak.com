(function () {
  var STORAGE_KEY = "jp_cookie_consent";

  function hasConsent() {
    try {
      return window.localStorage.getItem(STORAGE_KEY) === "accepted";
    } catch (e) {
      return false;
    }
  }

  function setConsent() {
    try {
      window.localStorage.setItem(STORAGE_KEY, "accepted");
    } catch (e) {
      // ignore
    }
  }

  function removeModal() {
    var backdrop = document.querySelector(".cookie-modal-backdrop");
    var modal = document.querySelector(".cookie-modal");
    if (backdrop && backdrop.parentNode) backdrop.parentNode.removeChild(backdrop);
    if (modal && modal.parentNode) modal.parentNode.removeChild(modal);
  }

  function createModal() {
    if (hasConsent()) return;

    var backdrop = document.createElement("div");
    backdrop.className = "cookie-modal-backdrop";

    var modal = document.createElement("div");
    modal.className = "cookie-modal";
    modal.setAttribute("role", "dialog");
    modal.setAttribute("aria-modal", "true");
    modal.setAttribute("aria-label", "Cookie preferences");

    modal.innerHTML = [
      '<div class="cookie-modal-header">',
      '  <div class="cookie-modal-title">Cookies and local storage</div>',
      '  <button type="button" class="cookie-modal-close" aria-label="Dismiss cookie banner">&times;</button>',
      "</div>",
      '<p class="cookie-modal-text">',
      "I use basic cookies and local storage to keep this site running smoothly and remember small preferences. ",
      'No ad networks, no tracking pixels. See the <a href="privacy.html">privacy policy</a> for details.',
      "</p>",
      '<ul class="cookie-category-list">',
      '  <li class="cookie-category-item">',
      '    <div>',
      '      <div class="cookie-category-label">Strictly necessary</div>',
      '      <div class="cookie-category-desc">Needed for things like remembering this choice and keeping basic features working.</div>',
      "    </div>",
      "  </li>",
      "</ul>",
      '<div class="cookie-modal-actions">',
      '  <button type="button" class="cookie-btn cookie-btn-primary" data-cookie-accept="all">Accept</button>',
      '  <button type="button" class="cookie-btn cookie-btn-outline" data-cookie-accept="essentials">Essentials only</button>',
      "</div>",
      '<div class="cookie-modal-footer">',
      '  <button type="button" data-cookie-manage="later">Decide later</button>',
      "</div>"
    ].join("");

    document.body.appendChild(backdrop);
    document.body.appendChild(modal);

    // Wire up actions
    var acceptButtons = modal.querySelectorAll("[data-cookie-accept]");
    acceptButtons.forEach(function (btn) {
      btn.addEventListener("click", function () {
        setConsent();
        removeModal();
      });
    });

    var closeBtn = modal.querySelector(".cookie-modal-close");
    if (closeBtn) {
      closeBtn.addEventListener("click", removeModal);
    }

    var decideLaterBtn = modal.querySelector("[data-cookie-manage='later']");
    if (decideLaterBtn) {
      decideLaterBtn.addEventListener("click", removeModal);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", createModal);
  } else {
    createModal();
  }
})();