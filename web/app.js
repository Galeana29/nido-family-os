// NIDO on the web.
//
// This screen decides nothing about the day. It sends the ledger to the engine compiled to
// WebAssembly and renders what comes back — same rule as the iOS app, no timing calculated here.
//
// The guidance (what to do, what to say when she refuses, the food, the safety note) never touches
// the engine either. It is the family plan, quoted, keyed by the name of the step.

import { WASI, File, OpenFile, ConsoleStdout } from "./vendor/browser_wasi_shim/index.js";

const STORE_KEY = "nido.state.v2";
const encoder = new TextEncoder();
const decoder = new TextDecoder();
const el = (id) => document.getElementById(id);

const T = {
  es: {
    day: "El día completo", rules: "Reglas de la casa", protocol: "Si no come",
    sources: "De dónde sale esto", demo: "Probar el día sin esperarlo",
    empty: "Nada pendiente por ahora.", adjusted: "ajustado", done: "hecho",
    real: "Hora real", simulated: "Reloj de prueba", how: "Cómo", delay: "+15 min", skip: "Hoy no",
    engine: "El motor de NIDO corre dentro de esta página, sin servidor.",
    stageMore: "Ver la etapa y el semáforo →", weaning: "Destete hoy", refuses: "Si protesta o rechaza",
    safety: "Seguridad", food: "Comida", portion: "Porción para empezar", drink: "Bebida",
    more: "Si pide más", less: "Si no come", closing: "Al cerrar", onWake: "Al despertar",
    development: "Qué practica", step: "Paso a paso", rate: "¿Cómo comió?",
    ratings: { none: "Nada", taste: "Probó", small: "Poco", normal: "Normal", more: "Más" },
    outOfWeek: "La semana del plan terminó. Te estoy repitiendo el último día hasta que carguen una nueva.",
    traffic: "¿Avanzo el destete o mantengo la etapa?", close: "Cerrar",
  },
  en: {
    day: "The whole day", rules: "House rules", protocol: "If she does not eat",
    sources: "Where this comes from", demo: "Walk the day without waiting for it",
    empty: "Nothing pending right now.", adjusted: "adjusted", done: "done",
    real: "Real time", simulated: "Test clock", how: "How", delay: "+15 min", skip: "Not today",
    engine: "The NIDO engine runs inside this page, with no server.",
    stageMore: "See the stage and the traffic light →", weaning: "Weaning today", refuses: "If she protests or refuses",
    safety: "Safety", food: "Food", portion: "Starting portion", drink: "Drink",
    more: "If she wants more", less: "If she does not eat", closing: "When closing", onWake: "On waking",
    development: "What this practises", step: "Step by step", rate: "How did she eat?",
    ratings: { none: "None", taste: "A taste", small: "A little", normal: "Normal", more: "More" },
    outOfWeek: "The planned week is over. Repeating the last day until a new one is loaded.",
    traffic: "Advance the weaning, or hold the stage?", close: "Close",
  },
};

let wasmModule = null;
let plan = null;
let fixtureText = null;
let planDay = null;
let today = null;
let lastResponse = null;

let state = load();

function load() {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (raw) return JSON.parse(raw);
  } catch (error) {
    console.warn("stored state could not be read, starting fresh", error);
  }
  return { language: "es", offsetMinutes: null, byDate: {} };
}

function save() {
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(state));
  } catch (error) {
    console.warn("state could not be saved", error);
  }
}

const t = () => T[state.language] || T.es;

function dayState() {
  if (!state.byDate[today]) state.byDate[today] = { events: null, overrides: [], previousPreferred: {} };
  return state.byDate[today];
}

/// The clock is the device clock. The offset exists only so the day can be walked through in a
/// minute while we are still building it; it is never on by default.
function now() {
  const base = Date.now() + (state.offsetMinutes || 0) * 60000;
  return new Date(base).toISOString();
}

function localDate() {
  const date = new Date(Date.now() + (state.offsetMinutes || 0) * 60000);
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Vancouver", year: "numeric", month: "2-digit", day: "2-digit",
  }).formatToParts(date);
  const get = (type) => parts.find((p) => p.type === type).value;
  return `${get("year")}-${get("month")}-${get("day")}`;
}

async function loadEngine() {
  const response = await fetch("nido.wasm");
  const total = Number(response.headers.get("content-length")) || 0;
  const reader = response.body.getReader();
  const chunks = [];
  let received = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    received += value.length;
    if (total) el("bootFill").style.width = `${Math.round((received / total) * 100)}%`;
  }
  const bytes = new Uint8Array(received);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  el("bootText").textContent = "Preparando el día…";
  wasmModule = await WebAssembly.compile(bytes);
  plan = await (await fetch("plan.json")).json();
}

/// Picks the day the family actually planned for. Past the end of the week the last day repeats,
/// and says so — silently inventing a routine would be worse than repeating a real one.
async function loadDay() {
  const dates = Object.keys(plan.days).sort();
  const wanted = localDate();
  today = plan.days[wanted] ? wanted : dates[dates.length - 1];
  planDay = plan.days[today];
  fixtureText = await (await fetch(`days/${today}.json`)).text();
}

/// One request, one fresh instance. The engine is deterministic, so nothing is lost by not keeping
/// it resident, and a failed tap can never poison the next one.
async function callEngine(request) {
  const stdin = new File(encoder.encode(JSON.stringify(request)));
  const stdout = new File(new Uint8Array());
  const wasi = new WASI([], [], [
    new OpenFile(stdin),
    new OpenFile(stdout),
    ConsoleStdout.lineBuffered((line) => console.warn("[nido]", line)),
  ]);
  const instance = await WebAssembly.instantiate(wasmModule, { wasi_snapshot_preview1: wasi.wasiImport });
  wasi.start(instance);
  const text = decoder.decode(stdout.data);
  if (!text.trim()) throw new Error("the engine returned nothing");
  return JSON.parse(text);
}

async function render(action) {
  const day = dayState();
  const request = {
    fixture: fixtureText,
    events: day.events,
    overrides: day.overrides,
    previousPreferred: day.previousPreferred,
    language: state.language,
    now: now(),
  };
  if (action) request.action = action;

  const response = await callEngine(request);
  if (!response.ok) {
    console.error(response.error);
    el("bootText").textContent = response.error;
    el("boot").hidden = false;
    el("boot").classList.remove("gone");
    return;
  }
  day.events = response.events;
  day.overrides = response.overrides;
  day.previousPreferred = response.previousPreferred;
  save();
  lastResponse = response;
  paint(response);
}

function guidanceFor(title) {
  return (planDay.guidance || {})[title] || null;
}

function paint(response) {
  const screen = response.screen;
  const words = t();

  el("greeting").textContent = screen.greeting;
  el("dateLine").textContent = `${screen.dateLine} · ${planDay.weekday}`;
  el("dayState").textContent = screen.dayState;
  el("lang").textContent = state.language.toUpperCase();

  const stage = planDay.stage || {};
  el("stageName").textContent = stage.stage || "";
  el("stageGoal").textContent = stage.goal || "";
  el("stageMore").textContent = words.stageMore;

  const card = screen.now;
  el("nowCard").hidden = !card;
  el("emptyCard").hidden = !!card;
  el("emptyText").textContent = words.empty;

  if (card) {
    const guidance = guidanceFor(card.title);
    el("eyebrow").textContent = card.eyebrow;
    el("title").textContent = card.title;
    el("timeRange").textContent = card.timeRange;
    el("statusLabel").textContent = card.statusLabel;
    el("primary").textContent = card.primaryActionLabel;
    el("primary").dataset.action = JSON.stringify(card.primaryAction);
    el("primary").dataset.rule = card.ruleID;
    el("primary").dataset.title = card.title;
    const why = el("explanation");
    why.hidden = !card.explanation;
    why.textContent = card.explanation || "";
    const food = el("nowFood");
    const menu = guidance && (guidance.menu ? guidance.menu.menu : guidance.food);
    food.hidden = !menu;
    food.textContent = menu || "";
    el("delay").textContent = words.delay;
    el("skip").textContent = words.skip;
    el("detail").textContent = words.how;
  }

  const notices = el("notices");
  notices.replaceChildren();
  if (planDay.repeated) {
    const li = document.createElement("li");
    li.textContent = words.outOfWeek;
    notices.append(li);
  }
  for (const notice of screen.notices) {
    const li = document.createElement("li");
    li.textContent = notice;
    notices.append(li);
  }

  el("dayTitle").textContent = words.day;
  const list = el("day");
  list.replaceChildren();
  for (const entry of response.day || []) {
    const li = document.createElement("li");
    li.className = "row";
    if (entry.isCurrent) li.classList.add("current");
    if (entry.isSettled) li.classList.add("settled");

    const time = document.createElement("span");
    time.className = "rowTime";
    time.textContent = entry.time;

    const body = document.createElement("span");
    body.className = "rowBody";
    const name = document.createElement("span");
    name.className = "rowName";
    name.textContent = entry.title;
    body.append(name);

    // The subtitle earns its line only if it says something the name does not.
    const guidance = guidanceFor(entry.title) || {};
    const detail = guidance.menu ? guidance.menu.menu
      : (guidance.title && guidance.title !== entry.title ? guidance.title : guidance.how);
    if (detail) {
      const sub = document.createElement("span");
      sub.className = "rowSub";
      sub.textContent = detail;
      body.append(sub);
    }

    const tag = document.createElement("span");
    tag.className = "rowTag";
    tag.textContent = entry.isSettled ? words.done : (entry.wasAdjusted ? words.adjusted : "");

    li.append(time, body, tag);
    li.addEventListener("click", () => openSheet(entry));
    list.append(li);
  }

  el("rulesTitle").textContent = words.rules;
  el("protocolTitle").textContent = words.protocol;
  el("sourcesTitle").textContent = words.sources;
  el("demoTitle").textContent = words.demo;
  el("engineNote").textContent = words.engine;
  el("clockKind").textContent = state.offsetMinutes ? words.simulated : words.real;
  el("clockNow").textContent = new Date(now()).toLocaleString(state.language === "es" ? "es-MX" : "en-CA", {
    timeZone: "America/Vancouver", hour: "2-digit", minute: "2-digit", hour12: false,
  });

  paintReference();
}

function paintReference() {
  const houseRules = el("houseRules");
  if (houseRules.childElementCount === 0) {
    for (const rule of plan.houseRules || []) {
      const li = document.createElement("li");
      li.textContent = rule;
      houseRules.append(li);
    }
    const protocols = el("protocols");
    for (const item of plan.protocols || []) {
      const block = document.createElement("div");
      block.className = "protocol";
      const head = document.createElement("p");
      head.className = "protocolHead";
      head.textContent = item.situation;
      if (item.level) {
        const level = document.createElement("span");
        level.className = `level level-${(item.level || "").toLowerCase()}`;
        level.textContent = item.level;
        head.append(level);
      }
      block.append(head);
      for (const [label, value] of [["Ahora", item.now], ["Nunca", item.never], ["Después", item.next]]) {
        if (!value) continue;
        const line = document.createElement("p");
        line.className = "protocolLine";
        line.innerHTML = `<b>${label}:</b> `;
        line.append(document.createTextNode(value));
        block.append(line);
      }
      protocols.append(block);
    }
    el("disclaimer").textContent = plan.disclaimer || "";
    const sources = el("sources");
    for (const source of plan.sources || []) {
      const li = document.createElement("li");
      const link = document.createElement("a");
      link.href = source.url;
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.textContent = `${source.org} · ${source.topic}`;
      li.append(link);
      if (source.says) {
        const says = document.createElement("span");
        says.className = "sourceSays";
        says.textContent = source.says;
        li.append(says);
      }
      sources.append(li);
    }
  }
}

// ------------------------------------------------------------------- sheets

function sheetSection(parent, label, value) {
  if (!value) return;
  const block = document.createElement("div");
  block.className = "sheetSection";
  const head = document.createElement("p");
  head.className = "sheetLabel";
  head.textContent = label;
  const body = document.createElement("p");
  body.className = "sheetText";
  body.textContent = value;
  block.append(head, body);
  parent.append(block);
}

function openSheet(entry) {
  const words = t();
  const guidance = guidanceFor(entry.title) || {};
  const content = el("sheetContent");
  content.replaceChildren();

  const header = document.createElement("div");
  header.className = "sheetHead";
  const title = document.createElement("h2");
  title.textContent = entry.title;
  const when = document.createElement("p");
  when.className = "sheetWhen";
  when.textContent = `${entry.timeRange} · ${entry.statusLabel}`;
  header.append(title, when);
  content.append(header);

  if (guidance.title && guidance.title !== entry.title) sheetSection(content, words.how, guidance.title);
  sheetSection(content, words.step, guidance.how);

  const menu = guidance.menu;
  if (menu) {
    sheetSection(content, words.food, menu.menu);
    sheetSection(content, words.portion, menu.portion);
    sheetSection(content, words.drink, menu.drink);
    sheetSection(content, words.more, menu.ifMore);
    sheetSection(content, words.less, menu.ifRefuses);
  } else {
    sheetSection(content, words.food, guidance.food);
  }

  sheetSection(content, words.weaning, guidance.weaning);
  sheetSection(content, words.refuses, guidance.ifRefuses);
  sheetSection(content, words.closing, guidance.closing);
  sheetSection(content, words.onWake, guidance.onWake);
  sheetSection(content, words.development, guidance.development);
  sheetSection(content, words.safety, guidance.safety || (menu && menu.safety));

  if (!entry.isSettled) {
    const act = document.createElement("button");
    act.className = "primary";
    act.textContent = entry.actionLabel;
    act.addEventListener("click", async () => {
      closeSheet();
      await render(entry.action);
      maybeRate(entry);
    });
    content.append(act);
  }

  const close = document.createElement("button");
  close.className = "sheetClose";
  close.textContent = words.close;
  close.addEventListener("click", closeSheet);
  content.append(close);

  el("sheet").hidden = false;
}

/// The rating exists in the domain and never reached a screen. It is the difference between knowing
/// a meal happened and knowing how it went, which is the whole question this week.
function maybeRate(entry) {
  const guidance = guidanceFor(entry.title);
  const isMeal = guidance && guidance.menu;
  const finished = entry.action && entry.action.kind === "finishMeal";
  if (!isMeal || !finished) return;

  const words = t();
  const content = el("sheetContent");
  content.replaceChildren();
  const head = document.createElement("div");
  head.className = "sheetHead";
  const title = document.createElement("h2");
  title.textContent = words.rate;
  const sub = document.createElement("p");
  sub.className = "sheetWhen";
  sub.textContent = entry.title;
  head.append(title, sub);
  content.append(head);

  const row = document.createElement("div");
  row.className = "ratings";
  for (const [key, label] of Object.entries(words.ratings)) {
    const button = document.createElement("button");
    button.textContent = label;
    button.addEventListener("click", async () => {
      closeSheet();
      await render({ kind: "rateMeal", ruleID: entry.ruleID, rating: key });
    });
    row.append(button);
  }
  content.append(row);

  const skip = document.createElement("button");
  skip.className = "sheetClose";
  skip.textContent = words.close;
  skip.addEventListener("click", closeSheet);
  content.append(skip);
  el("sheet").hidden = false;
}

function openStage() {
  const words = t();
  const stage = planDay.stage || {};
  const content = el("sheetContent");
  content.replaceChildren();

  const head = document.createElement("div");
  head.className = "sheetHead";
  const title = document.createElement("h2");
  title.textContent = stage.stage || "";
  const sub = document.createElement("p");
  sub.className = "sheetWhen";
  sub.textContent = stage.label || "";
  head.append(title, sub);
  content.append(head);

  sheetSection(content, "Meta", stage.goal);
  sheetSection(content, "Mañana", stage.morning);
  sheetSection(content, "Siesta 1", stage.nap1);
  sheetSection(content, "Siesta 2", stage.nap2);
  sheetSection(content, "Bedtime", stage.bedtime);
  sheetSection(content, "Noche", stage.night);
  sheetSection(content, "Avanzar o mantener", stage.advance);

  const trafficHead = document.createElement("p");
  trafficHead.className = "sheetLabel";
  trafficHead.textContent = words.traffic;
  content.append(trafficHead);
  for (const light of plan.traffic || []) {
    const block = document.createElement("div");
    block.className = `traffic traffic-${light.light.toLowerCase()}`;
    const name = document.createElement("p");
    name.className = "trafficName";
    name.textContent = `${light.light} · ${light.action}`;
    const signs = document.createElement("p");
    signs.className = "sheetText";
    signs.textContent = light.signs;
    block.append(name, signs);
    content.append(block);
  }

  const close = document.createElement("button");
  close.className = "sheetClose";
  close.textContent = words.close;
  close.addEventListener("click", closeSheet);
  content.append(close);
  el("sheet").hidden = false;
}

function closeSheet() {
  el("sheet").hidden = true;
}

// -------------------------------------------------------------------- wiring

function currentEntry() {
  return (lastResponse.day || []).find((entry) => entry.isCurrent);
}

function wire() {
  el("primary").addEventListener("click", async (event) => {
    const entry = currentEntry();
    await render(JSON.parse(event.currentTarget.dataset.action));
    if (entry) maybeRate(entry);
  });
  el("delay").addEventListener("click", () => render({ kind: "delay", ruleID: el("primary").dataset.rule, minutes: 15 }));
  el("skip").addEventListener("click", () => render({ kind: "skip", ruleID: el("primary").dataset.rule }));
  el("detail").addEventListener("click", () => { const entry = currentEntry(); if (entry) openSheet(entry); });
  el("stage").addEventListener("click", openStage);
  el("sheetBack").addEventListener("click", closeSheet);

  el("lang").addEventListener("click", async () => {
    state.language = state.language === "es" ? "en" : "es";
    document.documentElement.lang = state.language;
    save();
    await render();
  });

  el("plus15").addEventListener("click", async () => { state.offsetMinutes = (state.offsetMinutes || 0) + 15; save(); await render(); });
  el("plus60").addEventListener("click", async () => { state.offsetMinutes = (state.offsetMinutes || 0) + 60; save(); await render(); });
  el("realtime").addEventListener("click", async () => { state.offsetMinutes = null; save(); await loadDay(); await render(); });
  el("reset").addEventListener("click", async () => {
    state.byDate[today] = { events: null, overrides: [], previousPreferred: {} };
    save();
    await render();
  });

  // The day moves on its own while the phone sits on the counter.
  setInterval(() => { if (!state.offsetMinutes) render().catch((error) => console.warn(error)); }, 60000);
}

async function main() {
  try {
    await loadEngine();
    await loadDay();
    const dates = Object.keys(plan.days).sort();
    planDay.repeated = !plan.days[localDate()];
    document.documentElement.lang = state.language;
    wire();
    await render();
    el("boot").classList.add("gone");
    setTimeout(() => { el("boot").hidden = true; }, 400);
  } catch (error) {
    console.error(error);
    el("bootText").textContent = `No se pudo arrancar: ${error.message}`;
  }
}

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("sw.js").catch((error) => console.warn("sw", error));
  });
}

main();
