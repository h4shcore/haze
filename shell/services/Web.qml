pragma Singleton
import QtQuick
import Quickshell
import qs.common

// Web search for the launcher's "?" mode. "?foo" uses your default engine (Settings > Launcher);
// "?yt lofi", "?gh quickshell", "?nix ripgrep", "?w penguin", "?maps nagpur" pick one. A bare domain opens it.
Singleton {
    id: root

    readonly property var engines: ({
        ddg: { name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
        google: { name: "Google", url: "https://www.google.com/search?q=" },
        brave: { name: "Brave Search", url: "https://search.brave.com/search?q=" },
        yt: { name: "YouTube", url: "https://www.youtube.com/results?search_query=" },
        gh: { name: "GitHub", url: "https://github.com/search?q=" },
        nix: { name: "NixOS packages", url: "https://search.nixos.org/packages?query=" },
        w: { name: "Wikipedia", url: "https://en.wikipedia.org/w/index.php?search=" },
        maps: { name: "OpenStreetMap", url: "https://www.openstreetmap.org/search?query=" }
    })
    readonly property var also: ["yt", "gh", "nix", "w", "maps"]

    function open(url) { Quickshell.execDetached(["xdg-open", url]); }

    function row(key, terms) {
        const e = engines[key];
        return {
            id: "web:" + key,
            kind: "web",
            url: e.url + encodeURIComponent(terms),
            title: "Search " + e.name + " for “" + terms + "”",
            subtitle: "?" + key + " <terms>  ·  Enter to open"
        };
    }

    function rows(query) {
        const q = (query ?? "").trim();
        if (q === "") return [];
        const out = [];

        if (/^(https?:\/\/)?[\w-]+(\.[\w-]+)+(:\d+)?(\/\S*)?$/.test(q)) {
            const url = /^https?:\/\//.test(q) ? q : "https://" + q;
            out.push({ id: "web:url", kind: "web", url: url, title: "Open " + q, subtitle: url });
        }

        const m = q.match(/^(\S+)\s+(.+)$/);
        const key = m ? m[1].toLowerCase() : "";
        if (m && engines[key] !== undefined) {
            out.push(row(key, m[2]));
            for (const k of also) if (k !== key) out.push(row(k, m[2]));
            return out;
        }

        const def = engines[Settings.cfg.launcherSearchEngine] !== undefined ? Settings.cfg.launcherSearchEngine : "ddg";
        out.push(row(def, q));
        for (const k of also) out.push(row(k, q));
        return out;
    }
}
