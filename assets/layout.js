// assets/layout.js
// Injects shared header/footer partials into elements with data-include="header/footer".
// Keeps header/footer consistent across all pages.

(function () {
  function injectPartials() {
    var includeEls = document.querySelectorAll("[data-include]");
    if (!includeEls.length) {
      return;
    }

    includeEls.forEach(function (el) {
      var name = el.getAttribute("data-include");
      if (!name) return;

      var url = "partials/" + name + ".html";

      fetch(url, { credentials: "same-origin" })
        .then(function (response) {
          if (!response.ok) {
            console.warn("layout.js: Failed to load partial:", url, response.status);
            return "";
          }
          return response.text();
        })
        .then(function (html) {
          if (!html) return;
          // Replace placeholder div entirely with the partial HTML
          var container = document.createElement("div");
          container.innerHTML = html;
          // Move children out, keep DOM flatter
          while (container.firstChild) {
            el.parentNode.insertBefore(container.firstChild, el);
          }
          el.parentNode.removeChild(el);
        })
        .catch(function (err) {
          console.warn("layout.js: Error loading partial:", url, err);
        });
    });
  }

  if (
    document.readyState === "complete" ||
    document.readyState === "interactive"
  ) {
    injectPartials();
  } else {
    document.addEventListener("DOMContentLoaded", injectPartials);
  }
})();