(() => {
  "use strict";

  // Adds keyboard-visible focus styling helper if you want it later.
  // Safe no-op with your current CSS that already uses :focus-visible.
  function initFocusMode() {
    let usingKeyboard = false;

    window.addEventListener("keydown", (e) => {
      if (e.key === "Tab") {
        usingKeyboard = true;
        document.documentElement.classList.add("kbd");
      }
    }, { passive: true });

    window.addEventListener("mousedown", () => {
      if (usingKeyboard) {
        usingKeyboard = false;
        document.documentElement.classList.remove("kbd");
      }
    }, { passive: true });
  }

  document.addEventListener("DOMContentLoaded", () => {
    initFocusMode();
  });
})();