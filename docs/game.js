// UNO Online — tarayıcıda çalışan, Firebase Firestore ile gerçek zamanlı
// 2-4 kişilik UNO oyunu. Derleme/kurulum gerektirmez; GitHub Pages'te barınır.

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

const MAX_PLAYERS = 4;

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
const COLOR_TR = { red: "Kırmızı", yellow: "Sarı", green: "Yeşil", blue: "Mavi" };

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

// Sıradaki oyuncunun index'i (yönü ve adım sayısını dikkate alır).
function nextIndex(idx, dir, n, steps = 1) {
  return (((idx + dir * steps) % n) + n) % n;
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
    status: "waiting", // waiting -> playing -> finished
    players: [playerId], // players[0] = kurucu (host)
    playerNames: { [playerId]: name },
    hands: {},
    drawPile: [],
    discardPile: [],
    currentColor: "red",
    currentTurn: "",
    direction: 1,
    hasDrawn: false, // sırası olan oyuncu bu turda kart çekti mi?
    unoSafe: [], // "UNO" demiş ve 1 kartı olan oyuncular
    reverseColor: null, // reverse sonrası aktif renk kilidi
    winner: null,
    createdAt: Date.now(),
  });
  subscribe(code);
}

// unoSafe listesini yalnızca gerçekten 1 kartı olan oyuncularla sınırla.
function pruneUno(unoSafe, hands) {
  return (unoSafe || []).filter((p) => (hands[p] || []).length === 1);
}

async function joinGame(code, name) {
  lastError = null;
  const ref = doc(db, "games", code);
  try {
    await runTransaction(db, async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists()) throw new Error("Oda bulunamadı.");
      const g = snap.data();
      if (g.status !== "waiting") throw new Error("Oyun çoktan başladı.");
      const players = g.players || [];
      if (players.includes(playerId)) return; // yeniden bağlanma
      if (players.length >= MAX_PLAYERS) throw new Error(`Oda dolu (en fazla ${MAX_PLAYERS} kişi).`);
      players.push(playerId);
      const names = g.playerNames || {};
      names[playerId] = name;
      tx.update(ref, { players, playerNames: names });
    });
    subscribe(code);
  } catch (e) {
    lastError = e.message || String(e);
    render();
  }
}

// Yalnızca kurucu, en az 2 oyuncu varken oyunu başlatır.
async function startGame() {
  const ref = doc(db, "games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (g.status !== "waiting") return;
    const players = g.players || [];
    if (players[0] !== playerId) return; // sadece kurucu
    if (players.length < 2) return;

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
      hands,
      drawPile: deck,
      discardPile: [first],
      currentColor: first.color,
      currentTurn: players[0],
      direction: 1,
      hasDrawn: false,
      unoSafe: [],
      reverseColor: null,
      status: "playing",
    });
  });
}

async function playCard(cardId, chosenColor, targetId) {
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

    // Reverse sonrası özel kısıt: sadece aynı renk ya da başka bir reverse.
    const inReverse = g.reverseColor != null;
    if (inReverse) {
      const ok = card.type === "reverse" || card.color === g.reverseColor;
      if (!ok) return;
    } else {
      if (!canPlay(card, top, g.currentColor)) return;
      if (isWild(card) && !chosenColor) return;
    }

    hand.splice(idx, 1);
    const discard = [...g.discardPile, card];
    const draw = [...g.drawPile];
    const hands = { ...g.hands };
    hands[playerId] = hand;

    const players = g.players;
    const n = players.length;
    const curIdx = players.indexOf(playerId);
    const dir = g.direction || 1;
    const newColor = isWild(card) ? chosenColor : card.color;

    // Kart etkisine göre sırayı hesapla.
    const newDir = dir; // (bu varyantta reverse yön çevirmiyor)
    let steps = 1; // sayı / joker
    let keepTurn = false; // reverse: atan tekrar oynar
    let nextReverseColor = null; // reverse comboyu sürdürür/başlatır
    if (card.type === "skip") {
      steps = 2; // sıradaki atlanır
    } else if (card.type === "reverse") {
      keepTurn = true;
      nextReverseColor = card.color; // sonraki hamle bu renge/reverse'e kilitli
    } else if (card.type === "drawTwo") {
      // Hedef, atan oyuncu tarafından seçilir; atlanmaz (steps=1).
      const target = targetId && players.includes(targetId) && targetId !== playerId
        ? targetId : players[nextIndex(curIdx, dir, n, 1)];
      drawInto(hands, target, draw, discard, 2);
      steps = 1;
    } else if (card.type === "wildDrawFour") {
      const target = targetId && players.includes(targetId) && targetId !== playerId
        ? targetId : players[nextIndex(curIdx, dir, n, 1)];
      drawInto(hands, target, draw, discard, 4);
      steps = 1;
    }

    const nextTurn = keepTurn ? playerId : players[nextIndex(curIdx, newDir, n, steps)];

    let status = g.status;
    let winner = g.winner;
    if (hand.length === 0) {
      status = "finished";
      winner = playerId;
    }

    // UNO cezası: sıra, 1 kartı olup "UNO" dememiş bir oyuncuya (kendisi hariç)
    // dönüyorsa +2 kart. (kendi reverse zincirinde ceza yok)
    if (nextTurn !== playerId &&
        (hands[nextTurn] || []).length === 1 &&
        !(g.unoSafe || []).includes(nextTurn)) {
      drawInto(hands, nextTurn, draw, discard, 2);
    }

    // Kart oynandı → yeni oyuncunun turu, çekim sıfırlanır.
    const unoSafe = pruneUno(g.unoSafe, hands);

    tx.update(ref, {
      hands, drawPile: draw, discardPile: discard,
      currentColor: newColor, currentTurn: nextTurn, direction: newDir,
      hasDrawn: false, unoSafe, reverseColor: nextReverseColor,
      status, winner,
    });
  });
}

// Desteden 1 kart çeker. Sıra geçmez; oyuncu çektiği kartı oynayabilir ya da pas geçer.
async function drawCard() {
  const ref = doc(db, "games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (g.status !== "playing" || g.currentTurn !== playerId) return;
    if (g.hasDrawn) return; // bu turda zaten çekti

    const draw = [...g.drawPile];
    const discard = [...g.discardPile];
    const hands = { ...g.hands };
    drawInto(hands, playerId, draw, discard, 1);
    const unoSafe = pruneUno(g.unoSafe, hands);

    tx.update(ref, { hands, drawPile: draw, discardPile: discard, hasDrawn: true, unoSafe });
  });
}

// Kart çektikten sonra oynamak istemezse sırayı sonraki oyuncuya geçirir.
async function pass() {
  const ref = doc(db, "games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (g.status !== "playing" || g.currentTurn !== playerId) return;
    if (!g.hasDrawn) return; // önce kart çekmen gerekir

    const players = g.players;
    const curIdx = players.indexOf(playerId);
    const dir = g.direction || 1;
    const nextTurn = players[nextIndex(curIdx, dir, players.length, 1)];

    // UNO cezası: sıra 1 kartlı, UNO dememiş oyuncuya dönüyorsa +2.
    const draw = [...g.drawPile];
    const discard = [...g.discardPile];
    const hands = { ...g.hands };
    if (nextTurn !== playerId &&
        (hands[nextTurn] || []).length === 1 &&
        !(g.unoSafe || []).includes(nextTurn)) {
      drawInto(hands, nextTurn, draw, discard, 2);
    }
    const unoSafe = pruneUno(g.unoSafe, hands);

    tx.update(ref, {
      currentTurn: nextTurn, hasDrawn: false, unoSafe, reverseColor: null,
      hands, drawPile: draw, discardPile: discard,
    });
  });
}

// Tek kartı kalan oyuncu "UNO" der (yakalanmaktan kurtulur).
async function callUno() {
  const ref = doc(db, "games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if ((g.hands[playerId] || []).length !== 1) return;
    const unoSafe = pruneUno([...(g.unoSafe || []), playerId], g.hands);
    tx.update(ref, { unoSafe });
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

// Oyunu aynı oyuncularla yeniden başlatmak için bekleme odasına döndürür.
async function rematch() {
  const ref = doc(db, "games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (g.status !== "finished") return; // biri zaten sıfırlamış olabilir
    tx.update(ref, {
      status: "waiting",
      hands: {},
      drawPile: [],
      discardPile: [],
      currentColor: "red",
      currentTurn: "",
      direction: 1,
      hasDrawn: false,
      unoSafe: [],
      reverseColor: null,
      winner: null,
    });
  });
}

// Oyuncuyu odadan çıkarır (diğerleri devam edebilsin diye durumu düzeltir).
async function leaveRoom() {
  const id = gameId;
  if (!id) return leave();
  try {
    await runTransaction(db, async (tx) => {
      const ref = doc(db, "games", id);
      const snap = await tx.get(ref);
      if (!snap.exists()) return;
      const g = snap.data();
      if (!(g.players || []).includes(playerId)) return;

      const players = g.players.filter((p) => p !== playerId);
      const names = { ...g.playerNames }; delete names[playerId];
      const hands = { ...(g.hands || {}) }; delete hands[playerId];
      const updates = { players, playerNames: names, hands, unoSafe: pruneUno(g.unoSafe, hands) };

      if (players.length > 0 && g.status === "playing") {
        if (players.length < 2) {
          // Tek kişi kaldı → o kazanır.
          updates.status = "finished";
          updates.winner = players[0];
        } else if (g.currentTurn === playerId) {
          // Sırası olan çıktıysa sırayı sonraki oyuncuya ver.
          const old = g.players;
          const curIdx = old.indexOf(playerId);
          const dir = g.direction || 1;
          updates.currentTurn = old[nextIndex(curIdx, dir, old.length, 1)];
          updates.hasDrawn = false;
          updates.reverseColor = null;
        }
      }
      tx.update(ref, updates);
    });
  } catch (e) {
    // hata olsa da yerelden çık
  }
  leave();
}

// ------------------------------------------------------------------
// Görünüm (render)
// ------------------------------------------------------------------
function cardHtml(card, opts = {}) {
  const { faceDown = false, small = false, big = false, playable = false, clickable = false, colorOverride = null } = opts;
  const size = small ? " small" : big ? " big" : "";
  if (!card || faceDown) return `<div class="card back${size}">UNO</div>`;
  const color = colorOverride || card.color;
  const click = clickable ? ` data-card="${card.id}"` : "";
  const pl = playable ? " playable" : "";
  return `<div class="card ${color}${size}${pl}"${click}>${label(card)}</div>`;
}

function render() {
  if (!gameId) return renderHome();
  if (!state) return renderLoading();
  if (state.status === "waiting") return renderLobby();
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
      <div class="muted">2-4 kişi oynayabilir</div>
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

function renderLobby() {
  const players = state.players || [];
  const isHost = players[0] === playerId;
  const rows = players.map((p, i) => {
    const tags = [i === 0 ? "kurucu" : "", p === playerId ? "sen" : ""].filter(Boolean).join(" · ");
    return `
    <div class="lobby-row">
      <span>${escapeHtml(state.playerNames[p] || "Oyuncu")}</span>
      <span class="muted">${tags}</span>
    </div>`;
  }).join("");

  app.innerHTML = `
    <div class="center">
      <div style="font-size:20px;font-weight:700">Bekleme Odası</div>
      <div class="muted">Bu kodu paylaş:</div>
      <div class="code-box" id="codebox">${gameId} <span style="font-size:22px">📋</span></div>
      <div class="muted" id="copied"></div>

      <div class="lobby-list">${rows}</div>
      <div class="muted">${players.length}/${MAX_PLAYERS} oyuncu</div>

      ${isHost
        ? `<button class="btn-primary" id="start" ${players.length < 2 ? "disabled style='opacity:.5'" : ""}>
             Oyunu Başlat
           </button>
           ${players.length < 2 ? `<div class="muted">En az 2 oyuncu gerekiyor</div>` : ""}`
        : `<div class="muted">Kurucu başlatınca oyun başlayacak...</div><div class="spinner"></div>`}

      <button class="btn-outline" id="back" style="max-width:200px">Çık</button>
    </div>`;

  document.getElementById("codebox").onclick = () => {
    navigator.clipboard && navigator.clipboard.writeText(gameId);
    document.getElementById("copied").textContent = "Kopyalandı ✓";
  };
  document.getElementById("back").onclick = leaveRoom;
  const startBtn = document.getElementById("start");
  if (startBtn) startBtn.onclick = () => { if (state.players.length >= 2) startGame(); };
}

function renderBoard() {
  const players = state.players;
  const isMyTurn = state.currentTurn === playerId;
  const myHand = state.hands[playerId] || [];
  const top = state.discardPile[state.discardPile.length - 1];
  const dir = state.direction || 1;
  const hasDrawn = !!state.hasDrawn;
  const unoSafe = state.unoSafe || [];
  const reverseColor = state.reverseColor || null; // reverse kilidi (varsa)

  // Reverse kilidi varken sadece aynı renk ya da reverse oynanabilir.
  const playableNow = (c) => isMyTurn && (
    reverseColor != null
      ? (c.type === "reverse" || c.color === reverseColor)
      : canPlay(c, top, state.currentColor)
  );

  // Diğer oyuncular (sıra bende olandan sonra saat yönünde diz).
  const others = players.filter((p) => p !== playerId);
  const oppHtml = others.map((p) => {
    const count = (state.hands[p] || []).length;
    const isTurn = state.currentTurn === p;
    const safe = unoSafe.includes(p);
    const unoBit = count === 1
      ? (safe ? `<div class="uno-tag">UNO ✓</div>` : `<div class="uno-warn">1 kart! (UNO demedi)</div>`)
      : "";
    return `
      <div class="opp ${isTurn ? "opp-turn" : ""}">
        <div class="opp-name">${escapeHtml(state.playerNames[p] || "Oyuncu")}${isTurn ? " ⏳" : ""}</div>
        <div class="opp-cards">${
          Array.from({ length: Math.min(count, 8) }, () => cardHtml(null, { faceDown: true, small: true })).join("")
        }</div>
        <div class="muted">${count} kart</div>
        ${unoBit}
      </div>`;
  }).join("");

  // Kendi durumum: tek kartım varsa ve "UNO" demediysem uyarı butonu.
  const iNeedUno = myHand.length === 1 && !unoSafe.includes(playerId);

  const handHtml = myHand.map((c) =>
    cardHtml(c, { clickable: true, playable: playableNow(c) })
  ).join("");

  // Joker açık karttaysa, seçilen rengi herkes görsün diye o renkte göster.
  const topColorOverride = top && isWild(top) ? state.currentColor : null;

  app.innerHTML = `
    <div class="screen">
      <div class="topbar">
        <span class="muted">Oda: ${gameId}</span>
        <button class="leave-btn" id="leave">Çık</button>
      </div>
      <div class="opps">${oppHtml}</div>

      <div class="middle" style="background:${colorTint(state.currentColor)}">
        <div class="pile">
          <small>Deste</small>
          ${cardHtml(null, { faceDown: true, big: true })}
          <small>${isMyTurn ? (hasDrawn ? "çektin" : "çekmek için dokun") : ""}</small>
        </div>
        <div class="pile">
          <small>Açık kart</small>
          ${cardHtml(top, { big: true, colorOverride: topColorOverride })}
          <div class="color-badge">
            <span class="dot" style="background:${cssColor(state.currentColor)}"></span>
            ${COLOR_TR[state.currentColor] || ""} ${dir === 1 ? "↻" : "↺"}
          </div>
        </div>
      </div>

      <div class="turn ${isMyTurn ? "mine" : "theirs"}">
        ${isMyTurn ? "● Sıra sende" : "○ Sıra: " + escapeHtml(state.playerNames[state.currentTurn] || "Oyuncu")}
        ${isMyTurn && reverseColor != null
          ? `<div class="hint">↩️ Reverse! Sadece <b>${COLOR_TR[reverseColor] || reverseColor}</b> ya da başka bir Reverse oyna — yoksa çek/pas.</div>`
          : ""}
      </div>

      <div class="actions">
        ${isMyTurn && hasDrawn ? `<button class="btn-pass" id="pass">Pas Geç ▶</button>` : ""}
        ${iNeedUno ? `<button class="btn-uno" id="uno">📢 UNO! de</button>` : ""}
      </div>

      <div class="hand">${handHtml}</div>
    </div>`;

  document.getElementById("leave").onclick = leaveRoom;

  const deckEl = app.querySelector(".middle .pile .card.back");
  if (deckEl && isMyTurn && !hasDrawn) deckEl.onclick = drawCard;

  const passBtn = document.getElementById("pass");
  if (passBtn) passBtn.onclick = pass;
  const unoBtn = document.getElementById("uno");
  if (unoBtn) unoBtn.onclick = callUno;

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
      <button class="btn-primary" id="rematch" style="max-width:260px">🔁 Tekrar Oyna</button>
      <button class="btn-outline" id="leave" style="max-width:260px">Çık</button>
      <div class="muted">Tekrar Oyna herkesi bekleme odasına döndürür; kurucu yeniden başlatır.</div>
    </div>`;
  document.getElementById("rematch").onclick = rematch;
  document.getElementById("leave").onclick = leaveRoom;
}

// Kart oynama denemesi (joker ise renk, +2/+4 ise hedef sorar)
async function tryPlay(cardId) {
  const isMyTurn = state.currentTurn === playerId;
  const myHand = state.hands[playerId] || [];
  const card = myHand.find((c) => c.id === cardId);
  if (!card) return;
  const top = state.discardPile[state.discardPile.length - 1];
  const reverseColor = state.reverseColor || null;

  if (!isMyTurn) return toast("Sıra sende değil.");

  // Oynanabilirlik (reverse kilidi varsa ona göre).
  const ok = reverseColor != null
    ? (card.type === "reverse" || card.color === reverseColor)
    : canPlay(card, top, state.currentColor);
  if (!ok) {
    return toast(reverseColor != null
      ? `Reverse sonrası sadece ${COLOR_TR[reverseColor] || ""} ya da Reverse oynayabilirsin.`
      : "Bu kart oynanamaz.");
  }

  // Joker / +4 → renk seç.
  let chosenColor = null;
  if (card.type === "wild" || card.type === "wildDrawFour") {
    chosenColor = await pickColor();
    if (!chosenColor) return;
  }

  // +2 / +4 → kartların ekleneceği oyuncuyu seç.
  let targetId = null;
  if (card.type === "drawTwo" || card.type === "wildDrawFour") {
    targetId = await pickPlayer();
    if (!targetId) return;
  }

  playCard(cardId, chosenColor, targetId);
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

// +2/+4 kartının kime ekleneceğini seçtiren diyalog (kendisi hariç oyuncular).
function pickPlayer() {
  return new Promise((resolve) => {
    const targets = (state.players || []).filter((p) => p !== playerId);
    if (targets.length === 1) return resolve(targets[0]); // tek rakip → otomatik
    const ov = document.createElement("div");
    ov.className = "overlay";
    ov.innerHTML = `<div class="picker"><div style="font-weight:700">Kime eklensin?</div>
      <div class="picker-col">
        ${targets.map((p) => `<button class="target-btn" data-p="${p}">${escapeHtml(state.playerNames[p] || "Oyuncu")}
          <span class="muted">(${(state.hands[p] || []).length} kart)</span></button>`).join("")}
        <button class="target-cancel">İptal</button>
      </div></div>`;
    ov.querySelectorAll(".target-btn").forEach((b) => {
      b.onclick = () => { document.body.removeChild(ov); resolve(b.getAttribute("data-p")); };
    });
    ov.querySelector(".target-cancel").onclick = () => { document.body.removeChild(ov); resolve(null); };
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
      </div>
    </div>`;
}

// İlk çizim
render();
