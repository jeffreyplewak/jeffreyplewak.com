export default async function handler(req, res) {
  try {
    // Minimal, privacy-safe: do not store IP; do not set cookies.
    const type = (req.query && req.query.type) ? String(req.query.type) : "unknown";

    const event = {
      type,
      ts: new Date().toISOString(),
      ua: req.headers["user-agent"] || "",
      ref: req.headers.referer || ""
    };

    // Appears in Vercel logs. You can later pipe to a log drain.
    console.info("download_event", event);

    res.statusCode = 204;
    res.end();
  } catch (e) {
    // Never break the user flow.
    res.statusCode = 204;
    res.end();
  }
}