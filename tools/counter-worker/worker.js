// Visit counter for the book "R for Audit Analytics".
// A Cloudflare Worker with a D1 (SQLite) database bound as `DB`.
// It stores only page names and counts: no IP addresses, no cookies, no user data.
//
// Endpoints
//   POST /hit         body {"page": "/new-book/12-5PCA.html"}   adds 1, returns {"total": n}
//   GET  /badge.svg   a small badge image with the total visits
//   GET  /stats       page-wise counts as JSON, most visited first
//
// Table (create once in the D1 console):
//   CREATE TABLE IF NOT EXISTS counts (page TEXT PRIMARY KEY, n INTEGER NOT NULL DEFAULT 0);

const ALLOWED_ORIGINS = [
  "https://anilyayavar.github.io",
  "http://localhost:8000",            // local preview of the book
];
const BOOK_PREFIX = "/new-book/";     // only pages of the book are counted

function corsHeaders(request) {
  const origin = request.headers.get("Origin") || "";
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0],
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Vary": "Origin",
  };
}

async function total(env) {
  const row = await env.DB.prepare("SELECT COALESCE(SUM(n), 0) AS t FROM counts").first();
  return row ? row.t : 0;
}

function formatIndian(n) {
  // 1234567 -> 12,34,567
  const s = String(n);
  if (s.length <= 3) return s;
  const last3 = s.slice(-3);
  const rest = s.slice(0, -3).replace(/\B(?=(\d{2})+(?!\d))/g, ",");
  return rest + "," + last3;
}

function badge(label, value) {
  const w1 = 6 * label.length + 12, w2 = 7 * value.length + 12, w = w1 + w2;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="20" role="img" aria-label="${label}: ${value}">
<title>${label}: ${value}</title>
<rect width="${w1}" height="20" rx="3" fill="#555"/>
<rect x="${w1}" width="${w2}" height="20" rx="3" fill="#096B72"/>
<rect x="${w1}" width="4" height="20" fill="#096B72"/>
<g fill="#fff" text-anchor="middle" font-family="Verdana,DejaVu Sans,sans-serif" font-size="11">
<text x="${w1 / 2}" y="14">${label}</text>
<text x="${w1 + w2 / 2}" y="14">${value}</text>
</g></svg>`;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const cors = corsHeaders(request);

    if (request.method === "OPTIONS") return new Response(null, { headers: cors });

    if (url.pathname === "/hit" && request.method === "POST") {
      let page = "";
      try { page = String((await request.json()).page || ""); } catch (e) { /* ignore */ }
      // keep only the path of a book page, nothing else from the visitor
      page = page.split("?")[0].split("#")[0].slice(0, 200);
      if (!page.startsWith(BOOK_PREFIX)) {
        return Response.json({ error: "not a book page" }, { status: 400, headers: cors });
      }
      if (page.endsWith("/")) page += "index.html";
      await env.DB.prepare(
        "INSERT INTO counts (page, n) VALUES (?1, 1) ON CONFLICT(page) DO UPDATE SET n = n + 1"
      ).bind(page).run();
      return Response.json({ total: await total(env) }, { headers: cors });
    }

    if (url.pathname === "/badge.svg") {
      const svg = badge("visits", formatIndian(await total(env)));
      return new Response(svg, {
        headers: { ...cors, "Content-Type": "image/svg+xml", "Cache-Control": "max-age=300" },
      });
    }

    if (url.pathname === "/stats") {
      const { results } = await env.DB.prepare(
        "SELECT page, n FROM counts ORDER BY n DESC"
      ).all();
      return Response.json({ total: await total(env), pages: results }, { headers: cors });
    }

    return new Response("R for Audit Analytics visit counter", { headers: cors });
  },
};
