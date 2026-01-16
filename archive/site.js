(function () {
  const header = document.getElementById("main-header");
  if (header) {
    window.addEventListener("scroll", () => {
      header.classList.toggle("is-scrolled", window.scrollY > 20);
    }, { passive: true });
  }

  const year = document.getElementById("footer-year");
  if (year) year.textContent = new Date().getFullYear();

  const toggle = document.querySelector(".site-header-menu-toggle");
  if (toggle && header) {
    toggle.addEventListener("click", () => {
      header.classList.toggle("nav-open");
    });
  }
})();
