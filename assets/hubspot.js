// assets/hubspot.js
// Reusable HubSpot form loader for jeffreyplewak.com

(function () {
  // 1) Configure your HubSpot forms here
  // ------------------------------------
  // Replace YOUR_PORTAL_ID and FORM IDs with real values from HubSpot.
  const HUBSPOT_FORMS = {
    contact: {
      region: "na1",             // Check your HubSpot account region
      portalId: "YOUR_PORTAL_ID",
      formId: "YOUR_CONTACT_FORM_ID",
      target: "#hubspot-contact-form"
    },
    intake: {
      region: "na1",
      portalId: "YOUR_PORTAL_ID",
      formId: "YOUR_INTAKE_FORM_ID",
      target: "#hubspot-intake-form"
    }
    // Add more forms here if needed
    // anotherForm: { region: "na1", portalId: "XXX", formId: "YYY", target: "#..." }
  };

  const HUBSPOT_SCRIPT_SRC = "https://js.hsforms.net/forms/embed/v2.js";
  let hubspotScriptLoaded = false;
  let hubspotScriptLoading = false;
  const hubspotLoadQueue = [];

  // 2) Load HubSpot script once
  // ---------------------------
  function loadHubspotScript(callback) {
    if (hubspotScriptLoaded && window.hbspt && window.hbspt.forms) {
      callback();
      return;
    }

    hubspotLoadQueue.push(callback);

    if (hubspotScriptLoading) {
      return;
    }

    hubspotScriptLoading = true;

    const script = document.createElement("script");
    script.src = HUBSPOT_SCRIPT_SRC;
    script.async = true;
    script.charset = "utf-8";

    script.onload = function () {
      hubspotScriptLoaded = true;
      hubspotScriptLoading = false;
      while (hubspotLoadQueue.length > 0) {
        const cb = hubspotLoadQueue.shift();
        try {
          cb();
        } catch (err) {
          console.error("[hubspot.js] Error running queued callback", err);
        }
      }
    };

    script.onerror = function () {
      hubspotScriptLoading = false;
      console.error("[hubspot.js] Failed to load HubSpot forms script.");
    };

    document.head.appendChild(script);
  }

  // 3) Render a specific form by key (e.g. "contact" or "intake")
  // ------------------------------------------------------------
  function renderHubspotForm(name) {
    const cfg = HUBSPOT_FORMS[name];
    if (!cfg) {
      console.warn("[hubspot.js] No HubSpot config found for form name:", name);
      return;
    }

    const targetEl = document.querySelector(cfg.target);
    if (!targetEl) {
      console.warn("[hubspot.js] Target element not found for form:", name, "selector:", cfg.target);
      return;
    }

    loadHubspotScript(function () {
      if (!window.hbspt || !window.hbspt.forms || !window.hbspt.forms.create) {
        console.error("[hubspot.js] hbspt.forms.create not available after script load.");
        return;
      }

      window.hbspt.forms.create({
        region: cfg.region,
        portalId: cfg.portalId,
        formId: cfg.formId,
        target: cfg.target
      });
    });
  }

  // 4) Auto-initialize any DOM element with data-hubspot-form="<key>"
  // -----------------------------------------------------------------
  function autoInitHubspotForms() {
    const nodes = document.querySelectorAll("[data-hubspot-form]");
    if (!nodes.length) return;

    nodes.forEach(function (node) {
      const name = node.getAttribute("data-hubspot-form");
      if (!name) return;
      renderHubspotForm(name);
    });
  }

  document.addEventListener("DOMContentLoaded", autoInitHubspotForms);

  // 5) Expose a small API in case you ever want manual control
  // ----------------------------------------------------------
  window.siteHubspot = {
    render: renderHubspotForm,
    config: HUBSPOT_FORMS
  };
})();