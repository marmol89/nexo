#!/usr/bin/env node
// Busca código repetido entre los addons del repositorio.
//
//   node duplicados.js [raíz] [--min N] [--todo] [--guardar-base] [--json]
//
//   --min N          líneas significativas seguidas para contar como bloque (por defecto 5)
//   --todo           detalla todos los bloques, no solo los nuevos
//   --guardar-base   apunta los bloques de ahora como "ya conocidos" (duplicados.base.json)
//   --json           salida para programas
//
// Un addon es cada carpeta de la raíz que tiene un .toc (las que empiezan por "_" se ignoran).
// Informa de dos cosas:
//   1. Bloques: N o más líneas significativas seguidas que aparecen iguales en dos addons o más.
//   2. Nombres: funciones con el mismo nombre definidas en dos addons o más (pista, no prueba).
//
// Con una base guardada solo cuentan como fallo los bloques que no estaban en ella: así se ve
// si un cambio ha metido duplicación nueva aunque quede duplicación antigua por limpiar.
// Sale con código 1 si hay bloques nuevos (o cualquiera, si no hay base) y 0 si no.
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const BASE = path.join(__dirname, "duplicados.base.json");
const hash = text => crypto.createHash("sha1").update(text).digest("hex").slice(0, 12);

const args = process.argv.slice(2);
let root = process.cwd(), MIN = 5, asJson = false, showAll = false, saveBase = false;
for (let i = 0; i < args.length; i++) {
    if (args[i] === "--min") MIN = parseInt(args[++i], 10) || MIN;
    else if (args[i] === "--json") asJson = true;
    else if (args[i] === "--todo") showAll = true;
    else if (args[i] === "--guardar-base") saveBase = true;
    else root = args[i];
}

// Líneas que no dicen nada por sí solas: no cuentan para formar un bloque
const TRIVIAL = /^(end[),;]*|else|do|then|return|[{}()\[\],;]+|\}\)?,?|local \w+)$/;

function addons(dir) {
    return fs.readdirSync(dir, { withFileTypes: true })
        .filter(d => d.isDirectory() && !d.name.startsWith("_") && !d.name.startsWith("."))
        .filter(d => fs.readdirSync(path.join(dir, d.name)).some(f => f.endsWith(".toc")))
        .map(d => d.name);
}

function luaFiles(dir) {
    let out = [];
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name);
        if (e.isDirectory()) out = out.concat(luaFiles(p));
        else if (e.name.endsWith(".lua")) out.push(p);
    }
    return out;
}

// Quita el comentario de una línea sin tocar los "--" que van dentro de una cadena
function stripComment(line) {
    let quote = null;
    for (let i = 0; i < line.length; i++) {
        const c = line[i];
        if (quote) {
            if (c === "\\") i++;
            else if (c === quote) quote = null;
        } else if (c === '"' || c === "'") {
            quote = c;
        } else if (c === "-" && line[i + 1] === "-") {
            return line.slice(0, i);
        }
    }
    return line;
}

const names = addons(root);
const files = [];          // { addon, rel, lines: [{ n, text }] }
const funcs = new Map();   // nombre -> Map(addon -> "archivo:línea")

for (const addon of names) {
    for (const file of luaFiles(path.join(root, addon))) {
        const rel = path.relative(root, file).replace(/\\/g, "/");
        const lines = [];
        fs.readFileSync(file, "utf8").split(/\r?\n/).forEach((raw, i) => {
            const text = stripComment(raw).trim().replace(/\s+/g, " ");
            if (!text || TRIVIAL.test(text)) return;
            lines.push({ n: i + 1, text });
            const m = text.match(/^(?:local )?function (?:\w+[.:])?(\w+)\s*\(/);
            if (m) {
                if (!funcs.has(m[1])) funcs.set(m[1], new Map());
                if (!funcs.get(m[1]).has(addon)) funcs.get(m[1]).set(addon, rel + ":" + (i + 1));
            }
        });
        files.push({ addon, rel, lines });
    }
}

const windowText = (fi, i) => files[fi].lines.slice(i, i + MIN).map(l => l.text).join("\n");

// Ventanas de MIN líneas -> dónde aparecen
const windows = new Map();
files.forEach((f, fi) => {
    for (let i = 0; i + MIN <= f.lines.length; i++) {
        const key = windowText(fi, i);
        if (!windows.has(key)) windows.set(key, []);
        windows.get(key).push({ fi, i });
    }
});

// Une las ventanas consecutivas de una misma pareja de archivos en un solo bloque
const pairRuns = new Map();   // "fa|fb|desplazamiento" -> [i de fa]
for (const occ of windows.values()) {
    for (let a = 0; a < occ.length; a++) {
        for (let b = a + 1; b < occ.length; b++) {
            if (files[occ[a].fi].addon === files[occ[b].fi].addon) continue;
            const key = occ[a].fi + "|" + occ[b].fi + "|" + (occ[b].i - occ[a].i);
            if (!pairRuns.has(key)) pairRuns.set(key, []);
            pairRuns.get(key).push(occ[a].i);
        }
    }
}

// Base: ventanas repetidas que ya se conocían
let known = null;
if (fs.existsSync(BASE)) {
    const base = JSON.parse(fs.readFileSync(BASE, "utf8"));
    if (base.min === MIN) known = new Set(base.windows);
}

const dupWindows = new Set();
const blocks = [];
for (const [key, starts] of pairRuns) {
    const [fa, fb, off] = key.split("|").map(Number);
    starts.sort((x, y) => x - y);
    let s = starts[0], prev = starts[0];
    const flush = () => {
        const A = files[fa], B = files[fb];
        const len = prev - s + MIN;
        let isNew = !known;
        for (let w = s; w <= prev; w++) {
            const h = hash(windowText(fa, w));
            dupWindows.add(h);
            if (known && !known.has(h)) isNew = true;
        }
        blocks.push({
            lines: len,
            isNew,
            a: { file: A.rel, from: A.lines[s].n, to: A.lines[s + len - 1].n },
            b: { file: B.rel, from: B.lines[s + off].n, to: B.lines[s + off + len - 1].n },
            sample: A.lines.slice(s, s + Math.min(len, 4)).map(l => l.text),
        });
    };
    for (let k = 1; k < starts.length; k++) {
        if (starts[k] !== prev + 1) { flush(); s = starts[k]; }
        prev = starts[k];
    }
    flush();
}
blocks.sort((x, y) => y.lines - x.lines || x.a.file.localeCompare(y.a.file) || x.a.from - y.a.from);

if (saveBase) {
    fs.writeFileSync(BASE, JSON.stringify({ min: MIN, windows: [...dupWindows].sort() }) + "\n");
    console.log(`Base guardada con ${blocks.length} bloques conocidos: ${BASE}`);
    process.exit(0);
}

// Nombres de función repetidos; los de la interfaz común de cada addon no son duplicados
const EXPECTED = new Set(["InitDB", "Refresh", "Toggle", "OnInit", "OnDataChanged", "Tick"]);
const sameName = [...funcs.entries()]
    .filter(([name, where]) => where.size > 1 && !EXPECTED.has(name))
    .map(([name, where]) => ({ name, where: [...where.values()] }))
    .sort((x, y) => y.where.length - x.where.length || x.name.localeCompare(y.name));

const fresh = blocks.filter(b => b.isNew);
const shown = showAll || !known ? blocks : fresh;

// Líneas repetidas por pareja de addons: dónde está el grueso
const pairs = new Map();
for (const b of blocks) {
    const k = [b.a.file.split("/")[0], b.b.file.split("/")[0]].sort().join(" + ");
    pairs.set(k, (pairs.get(k) || 0) + b.lines);
}

if (asJson) {
    console.log(JSON.stringify({ addons: names, min: MIN, base: !!known, blocks, sameName }, null, 2));
} else {
    console.log(`Addons: ${names.join(", ")}  ·  bloque mínimo: ${MIN} líneas\n`);
    console.log(`BLOQUES REPETIDOS ENTRE ADDONS: ${blocks.length}`
        + (known ? `  ·  NUEVOS respecto a la base: ${fresh.length}` : "  (sin base guardada)"));
    for (const [k, n] of [...pairs.entries()].sort((x, y) => y[1] - x[1])) {
        console.log(`  ${String(n).padStart(5)} líneas  ${k}`);
    }
    if (known && !showAll && blocks.length > fresh.length) {
        console.log("\n(solo se detallan los nuevos; --todo los enseña todos)");
    }
    for (const b of shown) {
        console.log(`\n  ${known && b.isNew ? "NUEVO  " : ""}${b.lines} líneas  `
            + `${b.a.file}:${b.a.from}-${b.a.to}  =  ${b.b.file}:${b.b.from}-${b.b.to}`);
        for (const l of b.sample) console.log("      " + (l.length > 96 ? l.slice(0, 93) + "..." : l));
        if (b.lines > b.sample.length) console.log("      ...");
    }
    console.log(`\nFUNCIONES CON EL MISMO NOMBRE EN VARIOS ADDONS: ${sameName.length}`);
    for (const f of sameName) console.log(`  ${f.name}: ${f.where.join(", ")}`);
}
process.exit(fresh.length ? 1 : 0);
