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
      const channel = url.searchParams.get("channel") || env.CHANNEL || "@tessera_wallpapers";
      const limit = Math.min(parseInt(url.searchParams.get("limit") || "30", 10), 50);

      const botToken = env.BOT_TOKEN;
      if (!botToken) {
        return new Response(
          JSON.stringify({ error: "BOT_TOKEN not configured" }),
          { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      // Get updates from Telegram
      const tgUrl = `https://api.telegram.org/bot${botToken}/getUpdates?limit=${limit}&allowed_updates=message`;
      const tgResponse = await fetch(tgUrl, {
        headers: { "User-Agent": "Tessera-Sync/1.0" },
      });

      if (!tgResponse.ok) {
        const text = await tgResponse.text();
        return new Response(
          JSON.stringify({ error: "Telegram API error", details: text }),
          { status: tgResponse.status, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      const tgData = await tgResponse.json();
      if (!tgData.ok) {
        return new Response(
          JSON.stringify({ error: "Telegram returned error", details: tgData.description }),
          { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      const updates = tgData.result || [];
      const wallpapers = [];

      for (const update of updates) {
        const message = update.message;
        if (!message || message.chat?.type !== "channel") continue;

        const photos = message.photo;
        if (!photos || photos.length === 0) continue;

        const bestPhoto = photos[photos.length - 1];
        const fileId = bestPhoto.file_id;
        const caption = message.caption || message.text || "";

        let title = "Telegram Wallpaper";
        let photographer = "Telegram";
        let category = "Telegram";

        // Parse caption: "Title | Photographer, Category"
        const pipeIndex = caption.indexOf("|");
        if (pipeIndex >= 0) {
          title = caption.slice(0, pipeIndex).trim();
          const rest = caption.slice(pipeIndex + 1).trim();
          const parts = rest.split(",").map((s) => s.trim());
          photographer = parts[0] || "Telegram";
          if (parts.length > 1) category = parts[1];
        } else if (caption.trim().length > 0) {
          title = caption.trim();
        }

        // Get file URL
        const fileUrl = `https://api.telegram.org/bot${botToken}/getFile?file_id=${fileId}`;

        wallpapers.push({
          id: "telegram_" + fileId,
          title: title,
          photographer: photographer,
          category: category,
          width: bestPhoto.width,
          height: bestPhoto.height,
          file_id: fileId,
          url: fileUrl,
          date: new Date((message.date || 0) * 1000).toISOString(),
        });
      }

      return new Response(
        JSON.stringify({
          source: "telegram",
          channel: channel,
          count: wallpapers.length,
          wallpapers: wallpapers,
        }),
        { headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    } catch (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }
  },
};
