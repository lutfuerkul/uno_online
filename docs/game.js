// UNO Online — tarayıcıda çalışan, Firebase Firestore ile gerçek zamanlı
// 2 kişilik UNO oyunu. Derleme/kurulum gerektirmez; GitHub Pages'te barınır.

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js";
import {
  getFirestore, doc, setDoc, onSnapshot, runTransaction,
} from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";

// ------------------------------------------------------------------
// Kurulum / kimlik
// ------------------------------------------------------------------
const app = document.getElementById("app");

const cfg = window.FIREBASE_CONFIG;
if (!cfg || !cfg.projectId || cfg.projectId === "BURAYA_YAPISTIR") {
  showConfigHelp();
  throw new Error("Firebase config eksik");
}

const fb = initializeApp(cfg);
const db = getFirestore(fb);

// Her cihaza kalıcı bir oyuncu kimliği ver (yenilenince kaybolmasın).
let playerId = localStorage.getItem("uno_player");
if (!playerId) {
  playerId = (crypto.randomUUID && crypto.randomUUID()) || "p" + Date.now() + Math.random();
  localStorage.setItem("uno_player", playerId);
}
let playerName = localStorage.getItem("uno_name") || "";

// ------------------------------------------------------------------
// Oyun durumu (yerel)
// ------------------------------------------------------------------
let gameId = null;
let state = null;
let unsub = null;
let lastError = null;

// ------------------------------------------------------------------
// Kart mantığı
// ------------------------------------------------------------------
const COLORS = ["red", "yellow", "green", "blue"];

function uid() {
  return (crypto.randomUUID && crypto.randomUUID()) || "c" + Math.random().toString(36).slice(2);
}

function buildDeck() {
  const deck = [];
  for (const color of COLORS) {
    deck.push({ color, type: "number", value: 0, id: uid() });
    for (let v = 1; v <= 9; v++) {
      for (let i = 0; i < 2; i++) deck.push({ color, type: "number", value: v, id: uid() });
    }
    for (const type of ["skip", "reverse", "drawTwo"]) {
      for (let i = 0; i < 2; i++) deck.push({ color, type, value: null, id: uid() });
    }
  }
  for (let i = 0; i < 4; i++) {
    deck.push({ color: "wild", type: "wild", value: null, id: uid() });
    deck.push({ color: "wild", type: "wildDrawFour", value: null, id: uid() });
  }
  return deck;
}

function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

function isWild(c) {
  return c.type === "wild" || c.type === "wildDrawFour";
}

function canPlay(card, top, currentColor) {
  if (isWild(card)) return true;
  if (card.color === currentColor) return true;
  if (card.type === "number" && top.type === "number") return card.value === top.value;
  if (card.type === top.type && card.type !== "number") return true;
  return false;
}

function label(c) {
  switch (c.type) {
    case "number": return String(c.value);
    case "skip": return "⊘";
    case "reverse": return "⇄";
    case "drawTwo": return "+2";
    case "wild": return "JOKER";
    case "wildDrawFour": return "+4";
    default: return "?";
  }
}

// Desteden [player] eline [count] kart çeker; deste biterse yeniden karılır.
function drawInto(hands, player, draw, discard, count) {
  const hand = [...(hands[player] || [])];
  for (let i = 0; i < count; i++) {
    if (draw.length === 0) {
      reshuffle(draw, discard);
      if (draw.length === 0) break;
    }
    hand.push(draw.pop());
  }
  hands[player] = hand;
}

function reshuffle(draw, discard) {
  if (discard.length <= 1) return;
  const top = discard.pop();
  while (discard.length) draw.push(discard.pop());
  shuffle(draw);
  discard.push(top);
}

function genCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < 5; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

// ------------------------------------------------------------------
// Firestore işlemleri
// ------------------------------------------------------------------
async function createGame(name) {
  lastError = null;
  const code = genCode();
  await setDoc(doc(db, "games", code), {
    status: "waiting",
    players: [playerId],
    playerNames: { [playerId]: name },
    hands: {},
    drawPile: [],
    discardPile: [],
    currentColor: "red",
    currentTurn: "",
    winner: null,
    createdAt: Date.now(),
  });
  subscribe(code);
}

async function joinGame(code, name) {
  lastError = null;
  const ref = doc(db, "games", code);
  try {
    await runTransaction(db, async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists()) throw new Error("Oda bulunamadı.");
      const g = snap.data();
      const players = g.players || [];
      if (players.includes(playerId)) return;
      if (players.length >= 2) throw new Error("Bu oda dolu.");
      players.push(playerId);
      const names = g.playerNames || {};
      names[playerId] = name;

      // Oyunu başlat: deste kur, karıştır, 7'şer dağıt.
      const deck = shuffle(buildDeck());
      const hands = {};
      for (const p of players) hands[p] = Array.from({ length: 7 }, () => deck.pop());

      // İlk açık kart sayı kartı olsun.
      let first = deck.pop();
      while (first.type !== "number") {
        deck.unshift(first);
        first = deck.pop();
      }

      tx.update(ref, {
        players,
        playerNames: names,
        hands,
        drawPile: deck,
        discardPile: [first],
        currentColor: first.color,
        currentTurn: players[0],
        status: "playing",
      });
    });
    subscribe(code);
  } catch (e) {
    lastError = e.message || String(e);
    render();
  }
}

async function playCard(cardId, chosenColor) {
  const ref = doc(db, "games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (g.status !== "playing" || g.currentTurn !== playerId) return;

    const hand = [...(g.hands[playerId] || [])];
    const idx = hand.findIndex((c) => c.id === cardId);
    if (idx === -1) return;
    const card = hand[idx];
    const top = g.discardPile[g.discardPile.length - 1];
    if (!canPlay(card, top, g.currentColor)) return;
    if (isWild(card) && !chosenColor) return;

    hand.splice(idx, 1);
    const discard = [...g.discardPile, card];
    const draw = [...g.drawPile];
    const hands = { ...g.hands };
    hands[playerId] = hand;

    const opponent = g.players.find((p) => p !== playerId);
    const newColor = isWild(card) ? chosenColor : card.color;

    let nextTurn;
    if (card.type === "skip" || card.type === "reverse") {
      nextTurn = playerId; // 2 kişilikte rakip atlanır → tekrar sen
    } else if (card.type === "drawTwo") {
      drawInto(hands, opponent, draw, discard, 2);
      nextTurn = playerId;
    } else if (card.type === "wildDrawFour") {
      drawInto(hands, opponent, draw, discard, 4);
      nextTurn = playerId;
    } else {
      nextTurn = opponent;
    }

    let status = g.status;
    let winner = g.winner;
    if (hand.length === 0) {
      status = "finished";
      winner = playerId;
    }

    tx.update(ref, {
      hands, drawPile: draw, discardPile: discard,
      currentColor: newColor, currentTurn: nextTurn, status, winner,
    });
  });
}

async function drawCard() {
  const ref = doc(db, "games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (g.status !== "playing" || g.currentTurn !== playerId) return;

    const draw = [...g.drawPile];
    const discard = [...g.discardPile];
    const hands = { ...g.hands };
    drawInto(hands, playerId, draw, discard, 1);
    const opponent = g.players.find((p) => p !== playerId);

    tx.update(ref, { hands, drawPile: draw, discardPile: discard, currentTurn: opponent });
  });
}

function subscribe(code) {
  gameId = code;
  if (unsub) unsub();
  unsub = onSnapshot(doc(db, "games", code), (snap) => {
    state = snap.exists() ? snap.data() : null;
    render();
  });
  render();
}

function leave() {
  if (unsub) unsub();
  unsub = null;
  gameId = null;
  state = null;
  lastError = null;
  render();
}

// ------------------------------------------------------------------
// Görünüm (render)
// ------------------------------------------------------------------
function cardHtml(card, { faceDown = false, small = false, big = false, playable = false, clickable = false } = {}) {
  const size = small ? " small" : big ? " big" : "";
  if (!card || faceDown) return `<div class="card back${size}">UNO</div>`;
  const click = clickable ? ` data-card="${card.id}"` : "";
  const pl = playable ? " playable" : "";
  return `<div class="card ${card.color}${size}${pl}"${click}>${label(card)}</div>`;
}

function render() {
  if (!gameId) return renderHome();
  if (!state) return renderLoading();
  if (state.status === "waiting") return renderWaiting();
  if (state.status === "finished") return renderResult();
  return renderBoard();
}

function renderHome() {
  app.innerHTML = `
    <div class="center">
      <div>
        <div class="logo">UNO</div>
        <div class="logo-sub">ONLINE</div>
      </div>
      <input id="name" placeholder="İsmin" value="${escapeHtml(playerName)}" />
      <button class="btn-primary" id="create">Yeni Oyun Kur</button>
      <div class="divider"></div>
      <input id="code" placeholder="Oda Kodu (örn. K7P2M)" style="text-transform:uppercase" />
      <button class="btn-outline" id="join">Oyuna Katıl</button>
      ${lastError ? `<div class="error">${escapeHtml(lastError)}</div>` : ""}
    </div>`;

  const nameEl = document.getElementById("name");
  const codeEl = document.getElementById("code");
  const saveName = () => {
    playerName = nameEl.value.trim();
    localStorage.setItem("uno_name", playerName);
  };

  document.getElementById("create").onclick = () => {
    saveName();
    if (!playerName) return toast("Önce bir isim gir.");
    createGame(playerName);
  };
  document.getElementById("join").onclick = () => {
    saveName();
    if (!playerName) return toast("Önce bir isim gir.");
    const code = codeEl.value.trim().toUpperCase();
    if (!code) return toast("Oda kodunu gir.");
    joinGame(code, playerName);
  };
}

function renderLoading() {
  app.innerHTML = `<div class="center"><div class="spinner"></div>
    <div class="muted">Bağlanılıyor...</div>
    <button class="btn-outline" id="back" style="max-width:200px">Geri</button></div>`;
  document.getElementById("back").onclick = leave;
}

function renderWaiting() {
  app.innerHTML = `
    <div class="center">
      <div style="font-size:20px">Rakip bekleniyor...</div>
      <div class="muted">Bu kodu arkadaşınla paylaş:</div>
      <div class="code-box" id="codebox">${gameId} <span style="font-size:22px">📋</span></div>
      <div class="muted" id="copied"></div>
      <div class="spinner"></div>
      <button class="btn-outline" id="back" style="max-width:200px">İptal</button>
    </div>`;
  document.getElementById("codebox").onclick = () => {
    navigator.clipboard && navigator.clipboard.writeText(gameId);
    document.getElementById("copied").textContent = "Kopyalandı ✓";
  };
  document.getElementById("back").onclick = leave;
}

function renderBoard() {
  const isMyTurn = state.currentTurn === playerId;
  const myHand = state.hands[playerId] || [];
  const oppId = state.players.find((p) => p !== playerId) || "";
  const oppCount = (state.hands[oppId] || []).length;
  const oppName = state.playerNames[oppId] || "Rakip";
  const top = state.discardPile[state.discardPile.length - 1];

  const oppBacks = Array.from({ length: Math.min(oppCount, 12) },
    () => cardHtml(null, { faceDown: true, small: true })).join("");

  const handHtml = myHand.map((c) =>
    cardHtml(c, { clickable: true, playable: isMyTurn && canPlay(c, top, state.currentColor) })
  ).join("");

  app.innerHTML = `
    <div class="screen">
      <div class="opponent">
        <div><b>${escapeHtml(oppName)}</b></div>
        <div class="opp-cards">${oppBacks}</div>
        <div class="muted">${oppCount} kart</div>
      </div>

      <div class="middle" style="background:${colorTint(state.currentColor)}">
        <div class="pile">
          <small>Deste</small>
          ${cardHtml(null, { faceDown: true, big: true })}
          <small>${isMyTurn ? "çekmek için dokun" : ""}</small>
        </div>
        <div class="pile">
          <small>Açık kart</small>
          ${cardHtml(top, { big: true })}
        </div>
      </div>

      <div class="turn ${isMyTurn ? "mine" : "theirs"}">
        ${isMyTurn ? "● Sıra sende" : "○ Rakibin sırası"}
      </div>

      <div class="hand">${handHtml}</div>
    </div>`;

  // Desteye tıkla → kart çek
  const deckEl = app.querySelector(".middle .pile .card.back");
  if (deckEl && isMyTurn) deckEl.onclick = drawCard;

  // Eldeki kartlara tıkla → oyna
  app.querySelectorAll(".hand .card[data-card]").forEach((el) => {
    el.onclick = () => tryPlay(el.getAttribute("data-card"));
  });
}

function renderResult() {
  const iWon = state.winner === playerId;
  const winnerName = iWon ? "Sen" : (state.playerNames[state.winner] || "Rakip");
  app.innerHTML = `
    <div class="center">
      <div class="emoji">${iWon ? "🎉" : "😔"}</div>
      <div style="font-size:28px;font-weight:800">${iWon ? "Kazandın!" : "Kaybettin"}</div>
      <div class="muted">${escapeHtml(winnerName)} oyunu kazandı.</div>
      <button class="btn-primary" id="again" style="max-width:260px">Ana menüye dön</button>
    </div>`;
  document.getElementById("again").onclick = leave;
}

// Kart oynama denemesi (joker ise renk sorar)
async function tryPlay(cardId) {
  const isMyTurn = state.currentTurn === playerId;
  const myHand = state.hands[playerId] || [];
  const card = myHand.find((c) => c.id === cardId);
  if (!card) return;
  const top = state.discardPile[state.discardPile.length - 1];

  if (!isMyTurn) return toast("Sıra sende değil.");
  if (!canPlay(card, top, state.currentColor)) return toast("Bu kart oynanamaz.");

  if (isWild(card)) {
    const color = await pickColor();
    if (!color) return;
    playCard(cardId, color);
  } else {
    playCard(cardId, null);
  }
}

function pickColor() {
  return new Promise((resolve) => {
    const ov = document.createElement("div");
    ov.className = "overlay";
    ov.innerHTML = `<div class="picker"><div style="font-weight:700">Renk seç</div>
      <div class="picker-row">
        ${COLORS.map((c) => `<div class="swatch ${c}" data-c="${c}" style="background:${cssColor(c)}"></div>`).join("")}
      </div></div>`;
    ov.querySelectorAll(".swatch").forEach((s) => {
      s.onclick = () => { document.body.removeChild(ov); resolve(s.getAttribute("data-c")); };
    });
    document.body.appendChild(ov);
  });
}

// ------------------------------------------------------------------
// Yardımcılar
// ------------------------------------------------------------------
function cssColor(c) {
  return { red: "#d32f2f", yellow: "#f9a825", green: "#388e3c", blue: "#1976d2", wild: "#212121" }[c];
}
function colorTint(c) {
  return { red: "#d32f2f22", yellow: "#f9a82522", green: "#388e3c22", blue: "#1976d222", wild: "#ffffff11" }[c] || "#ffffff11";
}
function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (m) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[m]));
}
function toast(msg) {
  const t = document.createElement("div");
  t.textContent = msg;
  t.style.cssText = "position:fixed;bottom:24px;left:50%;transform:translateX(-50%);" +
    "background:#000c;color:#fff;padding:10px 18px;border-radius:20px;z-index:20;font-size:14px";
  document.body.appendChild(t);
  setTimeout(() => document.body.removeChild(t), 1800);
}

function showConfigHelp() {
  app.innerHTML = `
    <div class="center">
      <div class="emoji">🔧</div>
      <div style="font-size:22px;font-weight:800">Son bir adım kaldı</div>
      <div class="config-help">
        Oyunun çalışması için Firebase ayarlarını girmen gerekiyor:
        <ol>
          <li><b>console.firebase.google.com</b>'da yeni proje aç.</li>
          <li>Soldaki menüden <b>Firestore Database → Create</b> (test modu).</li>
          <li>Proje Ayarları → <b>Web uygulaması ekle</b> (&lt;/&gt; simgesi).</li>
          <li>Sana verdiği <code>apiKey</code>, <code>projectId</code> ... değerlerini
              <code>firebase-config.js</code> dosyasına yapıştır.</li>
        </ol>
        Bu dosyayı GitHub'da telefondan düzenleyebilirsin (kalem simgesi).
      </div>
    </div>`;
}

// İlk çizim
render();
