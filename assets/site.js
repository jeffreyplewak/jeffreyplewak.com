(() => {
  const header = document.getElementById('main-header');
  const toggle = document.querySelector('.site-header-menu-toggle');

  if (header) {
    window.addEventListener(
      'scroll',
      () => {
        header.classList.toggle('is-scrolled', window.scrollY > 10);
      },
      { passive: true }
    );
  }

  if (toggle && header) {
    toggle.addEventListener('click', () => {
      const open = header.classList.toggle('nav-open');
      toggle.setAttribute('aria-expanded', String(open));
      document.body.style.overflow = open ? 'hidden' : '';
    });
  }
})();
