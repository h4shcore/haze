pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Unit and currency conversion for the launcher: "12 km to mi", "72 f in c", "3 cups to ml", "100 usd to eur".
// Works as a plain query and after "=". Currency rates come from open.er-api.com (no key), cached for 12 hours.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/quickshell-haze"
    property bool ready: false

    // [dimension, factor to the base unit, ...names]
    readonly property var defs: [
        ["len", 1, "m", "meter", "meters", "metre", "metres"],
        ["len", 1000, "km", "kilometer", "kilometers", "kilometre", "kilometres"],
        ["len", 0.01, "cm", "centimeter", "centimeters", "centimetre", "centimetres"],
        ["len", 0.001, "mm", "millimeter", "millimeters", "millimetre", "millimetres"],
        ["len", 1609.344, "mi", "mile", "miles"],
        ["len", 0.9144, "yd", "yard", "yards"],
        ["len", 0.3048, "ft", "foot", "feet"],
        ["len", 0.0254, "in", "inch", "inches"],
        ["len", 1852, "nmi"],
        ["mass", 1, "kg", "kilogram", "kilograms", "kilo", "kilos"],
        ["mass", 0.001, "g", "gram", "grams"],
        ["mass", 0.000001, "mg"],
        ["mass", 0.45359237, "lb", "lbs", "pound", "pounds"],
        ["mass", 0.028349523125, "oz", "ounce", "ounces"],
        ["mass", 1000, "t", "tonne", "tonnes"],
        ["mass", 6.35029318, "st", "stone"],
        ["vol", 1, "l", "liter", "liters", "litre", "litres"],
        ["vol", 0.001, "ml", "milliliter", "milliliters", "millilitre", "millilitres"],
        ["vol", 3.785411784, "gal", "gallon", "gallons"],
        ["vol", 0.946352946, "qt", "quart", "quarts"],
        ["vol", 0.473176473, "pt", "pint", "pints"],
        ["vol", 0.2365882365, "cup", "cups"],
        ["vol", 0.029573529562, "floz"],
        ["vol", 0.01478676478, "tbsp"],
        ["vol", 0.00492892159, "tsp"],
        ["time", 1, "s", "sec", "secs", "second", "seconds"],
        ["time", 0.001, "ms"],
        ["time", 60, "min", "mins", "minute", "minutes"],
        ["time", 3600, "h", "hr", "hrs", "hour", "hours"],
        ["time", 86400, "d", "day", "days"],
        ["time", 604800, "wk", "week", "weeks"],
        ["speed", 1, "m/s", "mps"],
        ["speed", 0.2777777778, "km/h", "kph", "kmh", "kmph"],
        ["speed", 0.44704, "mph"],
        ["speed", 0.5144444444, "kn", "knot", "knots"],
        ["area", 1, "m2", "sqm"],
        ["area", 1000000, "km2"],
        ["area", 10000, "ha", "hectare", "hectares"],
        ["area", 4046.8564224, "acre", "acres"],
        ["area", 0.09290304, "ft2", "sqft"],
        ["data", 1, "b", "byte", "bytes"],
        ["data", 1000, "kb"],
        ["data", 1000000, "mb"],
        ["data", 1000000000, "gb"],
        ["data", 1000000000000, "tb"],
        ["data", 1024, "kib"],
        ["data", 1048576, "mib"],
        ["data", 1073741824, "gib"],
        ["data", 1099511627776, "tib"]
    ]

    readonly property var index: {
        const m = {};
        for (const d of defs)
            for (let i = 2; i < d.length; i++)
                m[d[i]] = { dim: d[0], f: d[1] };
        const temp = { c: "c", celsius: "c", degc: "c", f: "f", fahrenheit: "f", degf: "f", k: "k", kelvin: "k" };
        for (const n in temp) m[n] = { dim: "temp", k: temp[n] };
        return m;
    }

    readonly property var pattern: /^\s*(-?[\d,]*\.?\d+(?:e[+-]?\d+)?)\s*([a-z°][a-z0-9°\/²]*)\s+(?:to|in|as|into|->|=>|=)\s+([a-z°][a-z0-9°\/²]*)\s*$/i

    function norm(u) {
        return u.toLowerCase().replace(/°/g, "").replace(/²/g, "2");
    }

    function toC(v, k) { return k === "c" ? v : k === "f" ? (v - 32) * 5 / 9 : v - 273.15; }
    function fromC(v, k) { return k === "c" ? v : k === "f" ? v * 9 / 5 + 32 : v + 273.15; }

    function num(v) {
        if (v === 0) return "0";
        const a = Math.abs(v);
        if (a >= 1e15 || a < 1e-6) return v.toExponential(4).replace(/\.?0+e/, "e");
        return String(parseFloat(v.toPrecision(7)));
    }

    function makeRow(q, text, label) {
        return { id: "calc", kind: "calc", title: text, subtitle: label, text: text };
    }

    // ── currency ──
    property var live: null
    readonly property var cached: {
        try { return JSON.parse(store.adapter.json || "null"); }
        catch (err) { return null; }
    }
    readonly property var data: live ?? cached
    readonly property var rates: data?.rates ?? ({})

    function fetch() {
        if (net.running) return;
        if (data && Date.now() - data.t < 12 * 3600 * 1000) return;
        net.running = true;
    }

    function currency(v, a, b, label) {
        fetch();
        if (!data) return { id: "calc", kind: "calc", title: "Fetching rates…", subtitle: label, text: "" };
        if (!rates[a] || !rates[b]) return null;
        const out = v / rates[a] * rates[b];
        return makeRow(label, out.toFixed(2) + " " + b, label);
    }

    // a conversion row for a query like "12 km to mi", or null
    function auto(query) {
        const m = pattern.exec(query ?? "");
        if (!m) return null;
        const v = parseFloat(m[1].replace(/,/g, ""));
        if (!isFinite(v)) return null;
        const a = norm(m[2]);
        const b = norm(m[3]);
        const ua = index[a];
        const ub = index[b];
        const label = num(v) + " " + m[2] + " → " + m[3];

        if (ua && ub) {
            if (ua.dim !== ub.dim) return null;
            const out = ua.dim === "temp" ? fromC(toC(v, ua.k), ub.k) : v * ua.f / ub.f;
            if (!isFinite(out)) return null;
            return makeRow(query, num(out) + " " + m[3], label);
        }
        if (!ua && !ub && /^[a-z]{3}$/.test(a) && /^[a-z]{3}$/.test(b))
            return currency(v, a.toUpperCase(), b.toUpperCase(), label);
        return null;
    }

    Process {
        command: ["mkdir", "-p", root.dir]
        running: true
        onExited: root.ready = true
    }

    FileView {
        id: store
        path: root.ready ? root.dir + "/rates.json" : ""
        printErrors: false
        adapter: JsonAdapter {
            property string json: ""
        }
    }

    Process {
        id: net
        command: ["curl", "-fsS", "--max-time", "8", "-A", "Haze", "https://open.er-api.com/v6/latest/USD"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text);
                    if (o.result !== "success" || !o.rates) return;
                    root.live = { t: Date.now(), rates: o.rates };
                    store.adapter.json = JSON.stringify(root.live);
                    if (root.ready) store.writeAdapter();
                } catch (err) {}
            }
        }
    }
}
