import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const SRC = path.join(ROOT, "src");
const DIST = path.join(ROOT, "dist");

const read = (p) => fs.readFileSync(p, "utf8");
const write = (p, s) => {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, s);
};

const site = JSON.parse(read(path.join(SRC, "data", "site.json")));
const partialHeader = read(path.join(SRC, "partials", "header.html"));
const partialFooter = read(path.join(SRC, "partials", "footer.html"));

const jsonldPerson = JSON.stringify({
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Person",
      "name": site.name,
      "jobTitle": site.headline,
      "email": site.email ? `mailto:${site.email}` : undefined,
      "telephone": site.phone || undefined,
      "url": site.domain || undefined,
      "sameAs": [
        site.links.linkedin,
        site.links.github,
        site.links.reddit,
        site.links.upwork,
        site.links.fiverr,
        site.links.nextdoor
      ].filter(Boolean)
    },
    {
      "@type": "WebSite",
      "name": site.name,
      "url": site.domain || undefined
    }
  ]
}, null, 0);

const render = (html) => {
  // Very small, deterministic templater:
  // {{site.path.to.value}} and {{partial.header}} etc.
  return html
    .replaceAll("{{partial.header}}", partialHeader)
    .replaceAll("{{partial.footer}}", partialFooter)
    .replaceAll("{{jsonld.person}}", jsonldPerson)
    .replace(/\{\{site\.([a-zA-Z0-9_.]+)\}\}/g, (_, key) => {
      const parts = key.split(".");
      let cur = site;
      for (const p of parts) cur = (cur && cur[p] !== undefined) ? cur[p] : "";
      return String(cur ?? "");
    });
};

const copyDir = (from, to) => {
  fs.mkdirSync(to, { recursive: true });
  for (const ent of fs.readdirSync(from, { withFileTypes: true })) {
    const srcPath = path.join(from, ent.name);
    const dstPath = path.join(to, ent.name);
    if (ent.isDirectory()) copyDir(srcPath, dstPath);
    else fs.copyFileSync(srcPath, dstPath);
  }
};

const buildOnce = () => {
  fs.rmSync(DIST, { recursive: true, force: true });
  fs.mkdirSync(DIST, { recursive: true });

  // assets
  copyDir(path.join(SRC, "assets"), path.join(DIST, "assets"));

  // pages
  const pagesDir = path.join(SRC, "pages");
  for (const file of fs.readdirSync(pagesDir)) {
    if (!file.endsWith(".html")) continue;
    const out = render(read(path.join(pagesDir, file)));
    write(path.join(DIST, file), out);
  }
  console.log("[build] dist/ generated");
};

const watch = process.argv.includes("--watch");
buildOnce();

if (watch) {
  console.log("[watch] src/ -> dist/");
  fs.watch(SRC, { recursive: true }, () => {
    try { buildOnce(); } catch (e) { console.error(e); }
  });
}
