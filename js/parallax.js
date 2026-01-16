/**
 * parallax.js
 * Minimal parallax effect for background elements.
 * Only applies to elements with `.parallax-bg` class.
 * Respects user preference for reduced motion.
 */
(function () {
  "use strict";

  // Do nothing if user prefers reduced motion
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return;
  }

  /**
   * Checks for parallax elements and returns a NodeList.
   */
  function getParallaxElements() {
    return document.querySelectorAll(".parallax-bg");
  }

  /**
   * Simple parallax update: apply translateY to background
   * at a subtle ratio.
   */
  function updateParallax() {
    var scrollY = window.pageYOffset || document.documentElement.scrollTop;
    parallaxElems.forEach(function (el) {
      var speed = parseFloat(el.getAttribute("data-parallax-speed")) || 0.2;
      var offset = -(scrollY * speed);
      el.style.transform = "translateY(" + offset + "px)";
    });
  }

  /**
   * Initialization
   */
  function initParallax() {
    if (!parallaxElems || !parallaxElems.length) {
      return;
    }
    // Use passive scroll listener to avoid performance penalty
    window.addEventListener("scroll", updateParallax, { passive: true });
    // Also update on resize
    window.addEventListener("resize", updateParallax);

    // Initial call in case scroll is not at top
    updateParallax();
  }

  // Grab the elements once
  var parallaxElems = getParallaxElements();

  // Initialize on DOM ready
  if (document.readyState !== "loading") {
    initParallax();
  } else {
    document.addEventListener("DOMContentLoaded", initParallax);
  }

})();