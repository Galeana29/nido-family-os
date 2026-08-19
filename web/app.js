// NIDO on the web.
//
// The screen below decides nothing about the day. It sends the ledger to the engine compiled to
// WebAssembly, and renders whatever comes back. Same rule as the iOS app: no timing is ever
// calculated up here.

import { WASI, File, OpenFile, ConsoleStdout } from "./vendor/browser_wasi_shim/index.js";

const STORE_KEY = "nido.state.v1";
const encoder = new TextEncoder();
const decoder = new TextDecoder();

const el = (id) => document.getElementById(id);
const boot = el("boot");
const bootText = el("bootText");
const bootFill = el("bootFill");

let wasmModule = null;
let fixtureText = null;

/// Everything durable lives here. The engine is a pure function over it.
let state = load();

function load() {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (raw) return JSON.parse(raw);
  } catch (error) {
    console.warn("stored state could not be read, starting fresh", error);
  }
  return { events: null, overrides: [], previousPreferred: {}, language: "es", now: null };
}

function save() {
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(state));
  } catch (error) {
    console.warn("state could not be saved", error);
  }
}

async function loadEngine() {
  const wasmResponse = await fetch("nido.wasm");
  const total = Number(wasmResponse.headers.get("content-length")) || 0;
  const reader = wasmResponse.body.getReader();
  const chunks = [];
  let received = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    received += value.length;
    if (total) bootFill.style.width = `${Math.round((received / total) * 100)}%`;
  }
  const bytes = new Uint8Array(received);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  bootText.textContent = "Preparando el motor…";
  wasmModule = await WebAssembly.compile(bytes);
  fixtureText = await (await fetch("sample-day.json")).text();
}

/// One request, one fresh instance. The engine is deterministic, so nothing is lost by not keeping
/// it resident, and a crash can never poison the next tap.
async function callEngine(request) {
  const stdin = new File(encoder.encode(JSON.stringify(request)));
  const stdout = new File(new Uint8Array());
  const wasi = new WASI([], [], [
    new OpenFile(stdin),
    new OpenFile(stdout),
    ConsoleStdout.lineBuffered((line) => console.warn("[nido]", line)),
  ]);
  const instance = await WebAssembly.instantiate(wasmModule, {
    wasi_snapshot_preview1: wasi.wasiImport,
  });
  wasi.start(instance);
  const text = decoder.decode(stdout.data);
  if (!text.trim()) throw new Error("the engine returned nothing");
  return JSON.parse(text);
}

async function render(action) {
  const request = {
    fixture: fixtureText,
    events: state.events,
    overrides: state.overrides,
    previousPreferred: state.previousPreferred,
    language: state.language,
    now: state.now,
  };
  if (action) request.action = action;

  const response = await callEngine(request);
  if (!response.ok) {
    bootText.textContent = response.error || "algo salió mal";
    boot.hidden = false;
    boot.classList.remove("gone");
    return;
  }

  state.events = response.events;
  state.overrides = response.overrides;
  state.previousPreferred = response.previousPreferred;
  if (!state.now) state.now = response.now;
  save();
  paint(response.screen);
}

function paint(screen) {
  el("greeting").textContent = screen.greeting;
  el("dateLine").textContent = screen.dateLine;
  el("dayState").textContent = screen.dayState;
  el("lang").textContent = state.language.toUpperCase();

  const card = screen.now;
  el("nowCard").hidden = !card;
  el("emptyCard").hidden = !!card;

  if (card) {
    el("eyebrow").textContent = card.eyebrow;
    el("title").textContent = card.title;
    el("timeRange").textContent = card.timeRange;
    el("statusLabel").textContent = card.statusLabel;
    el("primary").textContent = card.primaryActionLabel;
    el("primary").dataset.action = JSON.stringify(card.primaryAction);
    el("primary").dataset.rule = card.ruleID;
    const why = el("explanation");
    why.hidden = !card.explanation;
    why.textContent = card.explanation || "";
  }

  const next = el("next");
  next.replaceChildren();
  for (const item of screen.next) {
    const li = document.createElement("li");
    const time = document.createElement("span");
    time.className = "t";
    time.textContent = item.time;
    const name = document.createElement("span");
    name.className = "n";
    name.textContent = item.title;
    li.append(time, name);
    if (item.wasAdjusted) {
      const flag = document.createElement("span");
      flag.className = "adj";
      flag.textContent = state.language === "es" ? "ajustado" : "adjusted";
      li.append(flag);
    }
    next.append(li);
  }

  const notices = el("notices");
  notices.replaceChildren();
  for (const notice of screen.notices) {
    const li = document.createElement("li");
    li.textContent = notice;
    notices.append(li);
  }

  el("clockNow").textContent = clockLabel(state.now);
  el("delay").textContent = state.language === "es" ? "+15 min" : "+15 min";
  el("skip").textContent = state.language === "es" ? "Hoy no" : "Not today";
  el("reset").textContent = state.language === "es" ? "Reiniciar el día" : "Restart the day";
  el("engineNote").textContent = state.language === "es"
    ? "El motor de NIDO corre dentro de esta página, sin servidor."
    : "The NIDO engine runs inside this page, with no server.";
}

function clockLabel(iso) {
  if (!iso) return "—";
  return new Date(iso).toLocaleString(state.language === "es" ? "es-MX" : "en-CA", {
    timeZone: "America/Vancouver",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

function shiftClock(minutes) {
  const base = state.now ? new Date(state.now) : new Date();
  state.now = new Date(base.getTime() + minutes * 60000).toISOString();
  save();
}

function wire() {
  el("primary").addEventListener("click", async (event) => {
    const action = JSON.parse(event.currentTarget.dataset.action);
    await render(action);
  });

  el("delay").addEventListener("click", async () => {
    await render({ kind: "delay", ruleID: el("primary").dataset.rule, minutes: 15 });
  });

  el("skip").addEventListener("click", async () => {
    await render({ kind: "skip", ruleID: el("primary").dataset.rule });
  });

  el("lang").addEventListener("click", async () => {
    state.language = state.language === "es" ? "en" : "es";
    document.documentElement.lang = state.language;
    save();
    await render();
  });

  el("plus15").addEventListener("click", async () => { shiftClock(15); await render(); });
  el("plus60").addEventListener("click", async () => { shiftClock(60); await render(); });

  el("reset").addEventListener("click", async () => {
    state = { events: null, overrides: [], previousPreferred: {}, language: state.language, now: null };
    save();
    await render();
  });
}

async function main() {
  try {
    await loadEngine();
    wire();
    await render();
    boot.classList.add("gone");
    setTimeout(() => { boot.hidden = true; }, 400);
  } catch (error) {
    console.error(error);
    bootText.textContent = `No se pudo arrancar: ${error.message}`;
  }
}

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("sw.js").catch((error) => console.warn("sw", error));
  });
}

main();
