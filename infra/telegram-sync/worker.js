// Tessera Telegram Sync Worker
//
// Serves wallpapers posted to a public Telegram channel. The previous version
// used getUpdates, but Telegram never delivers a bot's OWN channel posts back
// to it via getUpdates, so it always returned 0. This version scrapes the
// public preview page (https://t.me/s/<channel>), which needs no auth and is
// stable, then resolves full-resolution originals via the Wikimedia Commons
// API (the bot posts CC images from Commons and keeps the filename in the
// caption). The preview CDN is capped at 800px, so we prefer the Commons
// original and fall back to the CDN preview.
//
// Response shape is unchanged so the existing app decodes it as-is:
//   { source, channel, count, wallpapers: [
//       { id, title, photographer, category, width, height, file_id, url, date } ] }

const UA = { "User-Agent": "Mozilla/5.0 (compatible; TesseraSync/2.0)" };
const COMMONS_API = "https://commons.wikimedia.org/w/api.php";
const EXT_CANDIDATES = [".jpg", ".JPG", ".jpeg", ".png"];

export default {
  async fetch(request, env) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      const url = new URL(request.url);
      const channel = (url.searchParams.get("channel") || env.CHANNEL || "@tessera_wallpapers").replace(/^@/, "");
      const limit = Math.min(Math.max(parseInt(url.searchParams.get("limit") || "40", 10) || 40, 1), 100);
      const before = url.searchParams.get("before") || "";

      // --- Serve from cache when fresh ---
      const cacheKey = new Request(`https://tessera-sync.cache/${channel}?limit=${limit}&before=${before}`, { method: "GET" });
      const cache = caches.default;
      const cached = await cache.match(cacheKey);
      if (cached) return withCors(cached, corsHeaders);

      // --- Scrape the public preview page (paginate until we have enough) ---
      const messages = [];
      let cursor = before;
      let guard = 0;
      while (messages.length < limit && guard < 5) {
        guard++;
        const pageUrl = `https://t.me/s/${channel}${cursor ? `?before=${cursor}` : ""}`;
        const pageResp = await fetch(pageUrl, { headers: UA });
        if (!pageResp.ok) break;
        const html = await pageResp.text();
        const pageMsgs = parsePreviewPage(html, channel);
        if (pageMsgs.length === 0) break;
        messages.push(...pageMsgs);
        // next page: before the smallest message id seen
        const minId = Math.min(...pageMsgs.map((m) => m.msgId));
        if (!Number.isFinite(minId)) break;
        cursor = String(minId);
        if (pageMsgs.length < 2) break; // ran out of history
      }
      const selected = messages.slice(0, limit);

      // --- Resolve full-res originals via Wikimedia Commons ---
      const resolved = await resolveCommons(selected);

      const wallpapers = selected.map((m) => {
        const full = resolved.get(m.title);
        const src = full ? full.url : m.cdnUrl;
        return {
          id: `telegram_${m.msgId}`,
          title: m.title || "Telegram Wallpaper",
          photographer: m.photographer || "Telegram",
          category: m.category || "Telegram",
          width: full ? full.width : m.width,
          height: full ? full.height : m.height,
          file_id: String(m.msgId),
          url: src,
          date: m.date,
        };
      });

      const body = JSON.stringify({
        source: "telegram",
        channel: `@${channel}`,
        count: wallpapers.length,
        wallpapers,
      });

      const response = new Response(body, {
        headers: {
          "Content-Type": "application/json",
          // Cache 5 minutes at the edge and in browsers
          "Cache-Control": "public, s-maxage=300, max-age=60",
          ...corsHeaders,
        },
      });
      // Store a clone (Response body can only be consumed once)
      await cache.put(cacheKey, response.clone());
      return response;
    } catch (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }
  },
};

function withCors(response, corsHeaders) {
  const headers = new Headers(response.headers);
  for (const [k, v] of Object.entries(corsHeaders)) headers.set(k, v);
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}

// --- Parse the t.me/s/ preview HTML into message records ---
function parsePreviewPage(html, channel) {
  const out = [];
  const blocks = html.split('class="tgme_widget_message_wrap').slice(1);
  for (const block of blocks) {
    const idMatch = block.match(new RegExp(`data-post="${channel}/(\\d+)"`));
    const photoMatch = block.match(/background-image:url\('([^']+)'\)/);
    if (!idMatch || !photoMatch) continue;

    const capMatch = block.match(/tgme_widget_message_text[^>]*>([\s\S]*?)<\/div>/);
    const caption = capMatch ? decodeEntities(stripTags(capMatch[1])).trim() : "";

    // Caption format produced by the image bot: "File:<title> | <photographer>, <category>"
    let title = caption || "Telegram Wallpaper";
    let photographer = "Telegram";
    let category = "Telegram";
    const pipe = caption.indexOf("|");
    if (pipe >= 0) {
      title = caption.slice(0, pipe).trim();
      const rest = caption.slice(pipe + 1).trim();
      // Format is "Photographer, Category" but the photographer may itself
      // contain commas, so the category is the LAST comma-separated segment.
      const parts = rest.split(",").map((s) => s.trim()).filter(Boolean);
      if (parts.length >= 2) {
        category = parts[parts.length - 1];
        photographer = parts.slice(0, -1).join(", ");
      } else if (parts.length === 1) {
        photographer = parts[0];
      }
    }

    // Message date (unix seconds) if present
    let date = "";
    const dtMatch = block.match(/datetime="([^"]+)"/);
    if (dtMatch) date = dtMatch[1];

    out.push({
      msgId: parseInt(idMatch[1], 10),
      cdnUrl: photoMatch[1],
      title,
      photographer,
      category,
      width: 800,
      height: 533,
      date,
    });
  }
  return out;
}

// --- Resolve Wikimedia Commons originals for the caption titles ---
// The bot strips the file extension from captions, so try common extensions.
async function resolveCommons(messages) {
  const map = new Map(); // title -> { url, width, height }
  const titles = messages.map((m) => m.title).filter((t) => t && t.toLowerCase().startsWith("file:"));
  if (titles.length === 0) return map;

  // Build candidate -> title lookup
  const candidateToTitle = new Map();
  for (const t of titles) {
    for (const ext of EXT_CANDIDATES) candidateToTitle.set(t + ext, t);
  }
  const candidates = [...candidateToTitle.keys()];

  // Query in batches of 50 titles
  for (let i = 0; i < candidates.length; i += 50) {
    const batch = candidates.slice(i, i + 50);
    const params = new URLSearchParams({
      action: "query",
      format: "json",
      titles: batch.join("|"),
      prop: "imageinfo",
      iiprop: "url|size",
      iiurlwidth: "2560",
    });
    try {
      const resp = await fetch(`${COMMONS_API}?${params}`, { headers: UA });
      if (!resp.ok) continue;
      const data = await resp.json();
      const pages = (data.query && data.query.pages) || {};
      for (const page of Object.values(pages)) {
        if (!page.imageinfo || !page.imageinfo[0]) continue;
        const info = page.imageinfo[0];
        const title = candidateToTitle.get(page.title);
        if (!title || map.has(title)) continue;
        // Prefer a 2560px thumbnail (keeps it reasonable for mobile), else original
        map.set(title, {
          url: info.thumburl || info.url,
          width: info.thumbwidth || info.width || 0,
          height: info.thumbheight || info.height || 0,
        });
      }
    } catch (e) {
      // Non-fatal: fall back to CDN preview for these
    }
  }
  return map;
}

function stripTags(s) {
  return s.replace(/<[^>]+>/g, "");
}

function decodeEntities(s) {
  return s
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;/g, "'")
    .replace(/&nbsp;/g, " ");
}
