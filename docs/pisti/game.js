// Pişti Online — tarayıcıda çalışan, Firebase Firestore ile gerçek zamanlı
// 2-4 kişilik (herkes kendi başına, takım yok) Pişti oyunu. Klasik 52 kartlık
// standart iskambil destesi kullanılır. Derleme/kurulum gerektirmez;
// GitHub Pages'te barınır.

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

const MIN_PLAYERS = 2;
const MAX_PLAYERS = 4;

// Her cihaza kalıcı bir oyuncu kimliği ver (yenilenince kaybolmasın).
let playerId = localStorage.getItem("pisti_player");
if (!playerId) {
  playerId = (crypto.randomUUID && crypto.randomUUID()) || "p" + Date.now() + Math.random();
  localStorage.setItem("pisti_player", playerId);
}
let playerName = localStorage.getItem("pisti_name") || "";

// ------------------------------------------------------------------
// Oyun durumu (yerel)
// ------------------------------------------------------------------
let gameId = null;
let state = null;
let unsub = null;
let lastError = null;
let connecting = false;

// ------------------------------------------------------------------
// Kart mantığı
// ------------------------------------------------------------------
const SUITS = ["S", "H", "D", "C"]; // Maça, Kupa, Karo, Sinek
const SUIT_SYMBOL = { S: "♠", H: "♥", D: "♦", C: "♣" };
const SUIT_NAME = { S: "Maça", H: "Kupa", D: "Karo", C: "Sinek" };
const RED_SUITS = ["H", "D"];
const RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];

function uid() {
  return (crypto.randomUUID && crypto.randomUUID()) || "c" + Math.random().toString(36).slice(2);
}

function buildDeck() {
  const deck = [];
  for (const suit of SUITS) {
    for (const rank of RANKS) deck.push({ suit, rank, id: uid() });
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

function genCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < 5; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

function nextIndex(idx, n, steps = 1) {
  return ((idx + steps) % n + n) % n;
}

// ------------------------------------------------------------------
// El (round) kurulumu: 4'er kart dağıt + masaya 4 kart aç.
// Vale masaya açılan ilk kartlar arasındaysa, o kartlar destenin dibine
// konup yeniden 4 kart açılır (baştan bedava yakalama olmasın diye).
// ------------------------------------------------------------------
function dealHands(deck, players) {
  const hands = {};
  for (const p of players) hands[p] = deck.splice(deck.length - 4, 4);
  return hands;
}

function dealTable(deck) {
  let guard = 0;
  while (guard++ < 30) {
    const table = deck.splice(deck.length - 4, 4);
    if (!table.some((c) => c.rank === "J")) return table;
    // vale çıktıysa dibe göm, yeniden karıştır, tekrar dene
    deck.unshift(...table);
    shuffle(deck);
  }
  return deck.splice(deck.length - 4, 4); // pes edip devam (aşırı uç durum)
}

// ------------------------------------------------------------------
// Firestore işlemleri
// ------------------------------------------------------------------
function withTimeout(promise, ms, msg) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error(msg)), ms)),
  ]);
}

async function createGame(name) {
  lastError = null;
  connecting = true;
  render();
  try {
    const code = genCode();
    await withTimeout(
      setDoc(doc(db, "pisti_games", code), {
        status: "waiting", // waiting -> playing -> finished
        players: [playerId], // players[0] = kurucu (host)
        playerNames: { [playerId]: name },
        hands: {},
        pile: [],
        drawPile: [],
        won: {},
        pistiCount: {},
        lastCapturer: null,
        lastAction: null,
        currentTurn: "",
        winner: null,
        winners: [],
        scores: {},
        scoreDetail: {},
        createdAt: Date.now(),
      }),
      12000,
      "Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene."
    );
    connecting = false;
    subscribe(code);
  } catch (e) {
    connecting = false;
    lastError = _friendlyError(e);
    render();
  }
}

function _friendlyError(e) {
  return (e && e.message ? e.message : String(e)).replace(/^Error:\s*/, "");
}

async function joinGame(code, name) {
  lastError = null;
  connecting = true;
  render();
  const ref = doc(db, "pisti_games", code);
  try {
    await withTimeout(runTransaction(db, async (tx) => {
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
    }), 12000, "Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.");
    connecting = false;
    subscribe(code);
  } catch (e) {
    connecting = false;
    lastError = _friendlyError(e);
    render();
  }
}

// Sadece kurucu, 2-4 oyuncu varken oyunu başlatır.
async function startGame() {
  const ref = doc(db, "pisti_games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (g.status !== "waiting") return;
    const players = g.players || [];
    if (players[0] !== playerId) return; // sadece kurucu
    if (players.length < MIN_PLAYERS) return;

    const deck = shuffle(buildDeck());
    const hands = dealHands(deck, players);
    const pile = dealTable(deck);

    const won = {}, pistiCount = {};
    for (const p of players) { won[p] = []; pistiCount[p] = 0; }

    tx.update(ref, {
      hands, drawPile: deck, pile, won, pistiCount,
      lastCapturer: null, lastAction: null,
      currentTurn: players[0],
      winner: null, winners: [], scores: {}, scoreDetail: {},
      status: "playing",
    });
  });
}

function scoreGame(players, won, pistiCount) {
  let maxCards = -1;
  const cardCounts = {};
  for (const p of players) {
    cardCounts[p] = (won[p] || []).length;
    if (cardCounts[p] > maxCards) maxCards = cardCounts[p];
  }
  const detail = {};
  const scores = {};
  for (const p of players) {
    const cards = won[p] || [];
    const jackCount = cards.filter((c) => c.rank === "J").length;
    const hasAceSpades = cards.some((c) => c.suit === "S" && c.rank === "A");
    const hasTwoHearts = cards.some((c) => c.suit === "H" && c.rank === "2");
    const mostCards = cardCounts[p] === maxCards && maxCards > 0;
    const pisti = pistiCount[p] || 0;
    const total = pisti * 10 + jackCount * 1 + (hasAceSpades ? 1 : 0) + (hasTwoHearts ? 2 : 0) + (mostCards ? 3 : 0);
    detail[p] = { cardCount: cardCounts[p], jackCount, hasAceSpades, hasTwoHearts, mostCards, pisti, total };
    scores[p] = total;
  }
  let best = -1;
  for (const p of players) if (scores[p] > best) best = scores[p];
  const winners = players.filter((p) => scores[p] === best);
  return { scores, detail, winners };
}

// Kart oyna: elden bir kart masaya atılır; kurallara göre yakalama olur ya da olmaz.
async function playCard(cardId) {
  const ref = doc(db, "pisti_games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (g.status !== "playing" || g.currentTurn !== playerId) return;

    const hand = [...(g.hands[playerId] || [])];
    const idx = hand.findIndex((c) => c.id === cardId);
    if (idx === -1) return;
    const card = hand[idx];
    hand.splice(idx, 1);

    const pileBefore = [...(g.pile || [])];
    const top = pileBefore[pileBefore.length - 1];

    let captured = false;
    let isPisti = false;
    if (card.rank === "J") {
      captured = pileBefore.length > 0;
    } else if (pileBefore.length > 0 && top.rank === card.rank) {
      captured = true;
      isPisti = pileBefore.length === 1;
    }

    const hands = { ...g.hands, [playerId]: hand };
    const won = { ...g.won };
    const pistiCount = { ...g.pistiCount };
    let pile;
    let lastCapturer = g.lastCapturer;
    let lastAction = { player: playerId, card, captured, isPisti };

    if (captured) {
      won[playerId] = [...(won[playerId] || []), ...pileBefore, card];
      pile = [];
      lastCapturer = playerId;
      if (isPisti) pistiCount[playerId] = (pistiCount[playerId] || 0) + 1;
    } else {
      pile = [...pileBefore, card];
    }

    const players = g.players;
    const curIdx = players.indexOf(playerId);
    let nextTurn = players[nextIndex(curIdx, players.length, 1)];

    const allHandsEmpty = players.every((p) => (hands[p] || []).length === 0);
    let drawPile = [...(g.drawPile || [])];
    let status = g.status;
    let winner = null, winners = [], scores = {}, scoreDetail = {};

    if (allHandsEmpty) {
      if (drawPile.length > 0) {
        // yeni el: herkese 4'er kart daha dağıt (masa aynen kalır)
        for (const p of players) {
          hands[p] = drawPile.splice(drawPile.length - 4, 4);
        }
      } else {
        // deste bitti, kimsenin eli kalmadı → oyun bitti
        if (pile.length > 0 && lastCapturer) {
          won[lastCapturer] = [...(won[lastCapturer] || []), ...pile];
          pile = [];
        }
        const result = scoreGame(players, won, pistiCount);
        scores = result.scores;
        scoreDetail = result.detail;
        winners = result.winners;
        winner = winners.length === 1 ? winners[0] : null;
        status = "finished";
      }
    }

    tx.update(ref, {
      hands, pile, drawPile, won, pistiCount, lastCapturer, lastAction,
      currentTurn: status === "finished" ? g.currentTurn : nextTurn,
      status, winner, winners, scores, scoreDetail,
    });
  });
}

function subscribe(code) {
  gameId = code;
  if (unsub) unsub();
  unsub = onSnapshot(doc(db, "pisti_games", code), (snap) => {
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

async function rematch() {
  const ref = doc(db, "pisti_games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (g.status !== "finished") return;
    tx.update(ref, {
      status: "waiting",
      hands: {}, pile: [], drawPile: [], won: {}, pistiCount: {},
      lastCapturer: null, lastAction: null, currentTurn: "",
      winner: null, winners: [], scores: {}, scoreDetail: {},
    });
  });
}

async function leaveRoom() {
  const id = gameId;
  if (!id) return leave();
  try {
    await runTransaction(db, async (tx) => {
      const ref = doc(db, "pisti_games", id);
      const snap = await tx.get(ref);
      if (!snap.exists()) return;
      const g = snap.data();
      if (!(g.players || []).includes(playerId)) return;

      const players = g.players.filter((p) => p !== playerId);
      const names = { ...g.playerNames }; delete names[playerId];
      const hands = { ...(g.hands || {}) }; delete hands[playerId];
      const updates = { players, playerNames: names, hands };

      if (g.status === "playing") {
        if (players.length < MIN_PLAYERS) {
          // yeterli oyuncu kalmadı → kalan(lar) yakaladıkları kartlarla kazanır
          const result = scoreGame(players, g.won || {}, g.pistiCount || {});
          updates.status = "finished";
          updates.scores = result.scores;
          updates.scoreDetail = result.detail;
          updates.winners = result.winners;
          updates.winner = result.winners.length === 1 ? result.winners[0] : null;
        } else if (g.currentTurn === playerId) {
          // Sırası olan çıktıysa sırayı bir sonraki (kalan) oyuncuya ver.
          const old = g.players;
          const curIdx = old.indexOf(playerId);
          const afterPlayer = old[nextIndex(curIdx, old.length, 1)];
          updates.currentTurn = players.includes(afterPlayer) ? afterPlayer : players[0];
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
// Görünüm (render) — klasik iskambil kağıdı çizimi
// ------------------------------------------------------------------
function cardHtml(card, opts = {}) {
  const { faceDown = false, small = false, big = false, clickable = false, dim = false } = opts;
  const w = small ? 34 : big ? 84 : 62;
  const sv = `--w:${w}px`;

  if (!card || faceDown) {
    return `<div class="card back" style="${sv}"><span class="back-pattern"></span></div>`;
  }

  const red = RED_SUITS.includes(card.suit);
  const cls = red ? "red" : "black";
  const sym = SUIT_SYMBOL[card.suit];
  const click = clickable ? ` data-card="${card.id}"` : "";
  const dimCls = dim ? " dim" : "";

  return `<div class="card face ${cls}${dimCls}" style="${sv}"${click}>
      <span class="corner tl">${card.rank}<br/>${sym}</span>
      <span class="center-pip">
        <span class="suit-big">${sym}</span>
      </span>
      <span class="corner br">${card.rank}<br/>${sym}</span>
    </div>`;
}

function render() {
  if (connecting) return renderConnecting();
  if (!gameId) return renderHome();
  if (!state) return renderLoading();
  if (state.status === "waiting") return renderLobby();
  if (state.status === "finished") return renderResult();
  return renderBoard();
}

function renderConnecting() {
  app.innerHTML = `<div class="center"><div class="spinner"></div>
    <div class="muted">Bağlanılıyor...</div></div>`;
}

function renderHome() {
  app.innerHTML = `
    <div class="center">
      <div>
        <div class="logo">PİŞTİ</div>
        <div class="logo-sub">ONLINE</div>
      </div>
      <input id="name" placeholder="İsmin" value="${escapeHtml(playerName)}" />
      <button class="btn-primary" id="create">Yeni Oyun Kur</button>
      <div class="divider"></div>
      <input id="code" placeholder="Oda Kodu (örn. K7P2M)" style="text-transform:uppercase" />
      <button class="btn-outline" id="join">Oyuna Katıl</button>
      <div class="muted">2-4 kişi oynayabilir · takım yok, herkes kendi başına</div>
      ${lastError ? `<div class="error">${escapeHtml(lastError)}</div>` : ""}
    </div>`;

  const nameEl = document.getElementById("name");
  const codeEl = document.getElementById("code");
  const saveName = () => {
    playerName = nameEl.value.trim();
    localStorage.setItem("pisti_name", playerName);
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
        ? `<button class="btn-primary" id="start" ${players.length < MIN_PLAYERS ? "disabled style='opacity:.5'" : ""}>
             Oyunu Başlat
           </button>
           ${players.length < MIN_PLAYERS ? `<div class="muted">En az 2 oyuncu gerekiyor</div>` : ""}`
        : `<div class="muted">Kurucu başlatınca oyun başlayacak...</div><div class="spinner"></div>`}

      <button class="btn-outline" id="back" style="max-width:200px">Çık</button>
    </div>`;

  document.getElementById("codebox").onclick = () => {
    navigator.clipboard && navigator.clipboard.writeText(gameId);
    document.getElementById("copied").textContent = "Kopyalandı ✓";
  };
  document.getElementById("back").onclick = leaveRoom;
  const startBtn = document.getElementById("start");
  if (startBtn) startBtn.onclick = () => { if (state.players.length >= MIN_PLAYERS) startGame(); };
}

function renderBoard() {
  const players = state.players;
  const isMyTurn = state.currentTurn === playerId;
  const myHand = state.hands[playerId] || [];
  const pile = state.pile || [];
  const top = pile[pile.length - 1];
  const deckCount = (state.drawPile || []).length;

  const others = players.filter((p) => p !== playerId);
  const oppHtml = others.map((p) => {
    const count = (state.hands[p] || []).length;
    const wonCount = (state.won[p] || []).length;
    const isTurn = state.currentTurn === p;
    return `
      <div class="opp ${isTurn ? "opp-turn" : ""}">
        <div class="opp-name">${escapeHtml(state.playerNames[p] || "Oyuncu")}${isTurn ? " ⏳" : ""}</div>
        <div class="opp-cards">${
          Array.from({ length: Math.min(count, 4) }, () => cardHtml(null, { faceDown: true, small: true })).join("")
        }</div>
        <div class="muted">${count} elde · ${wonCount} kazandı</div>
      </div>`;
  }).join("");

  const myWon = (state.won[playerId] || []).length;
  const lastAction = state.lastAction;
  const lastActionHtml = lastAction
    ? `<div class="last-action">${escapeHtml(state.playerNames[lastAction.player] || "Oyuncu")}
        ${lastAction.card.rank}${SUIT_SYMBOL[lastAction.card.suit]} oynadı
        ${lastAction.isPisti ? " — <b>PİŞTİ! 🎉</b>" : lastAction.captured ? " — yaktı! 🔥" : ""}</div>`
    : "";

  const handHtml = myHand.map((c) =>
    cardHtml(c, { clickable: isMyTurn, dim: !isMyTurn })
  ).join("");

  app.innerHTML = `
    <div class="screen">
      <div class="topbar">
        <span class="muted">Oda: ${gameId}</span>
        <button class="leave-btn" id="leave">Çık</button>
      </div>
      <div class="opps">${oppHtml}</div>

      <div class="middle">
        <div class="pile">
          <small>Deste (${deckCount})</small>
          ${deckCount > 0 ? cardHtml(null, { faceDown: true, big: true }) : `<div class="empty-slot">boş</div>`}
        </div>
        <div class="pile">
          <small>Masa (${pile.length})</small>
          ${top ? cardHtml(top, { big: true }) : `<div class="empty-slot">boş</div>`}
        </div>
        <div class="pile">
          <small>Sende</small>
          <div class="mini-stat">${myWon} 🂠</div>
        </div>
      </div>

      ${lastActionHtml}

      <div class="turn ${isMyTurn ? "mine" : "theirs"}">
        ${isMyTurn ? "● Sıra sende — bir kart oyna" : "○ Sıra: " + escapeHtml(state.playerNames[state.currentTurn] || "Oyuncu")}
      </div>

      <div class="hand">${handHtml}</div>
    </div>`;

  document.getElementById("leave").onclick = leaveRoom;

  app.querySelectorAll(".hand .card[data-card]").forEach((el) => {
    el.onclick = () => tryPlay(el.getAttribute("data-card"));
  });
}

function renderResult() {
  const players = state.players || [];
  const winners = state.winners || (state.winner ? [state.winner] : []);
  const iWon = winners.includes(playerId);
  const tie = winners.length > 1;
  const title = tie ? "Berabere!" : iWon ? "Kazandın!" : "Kaybettin";
  const emoji = tie ? "🤝" : iWon ? "🎉" : "😔";

  const rows = [...players].sort((a, b) => (state.scores[b] || 0) - (state.scores[a] || 0)).map((p) => {
    const d = (state.scoreDetail && state.scoreDetail[p]) || {};
    const isMe = p === playerId;
    const won = winners.includes(p);
    return `
      <div class="score-row ${won ? "score-win" : ""}">
        <div class="score-name">${won ? "👑 " : ""}${escapeHtml(state.playerNames[p] || "Oyuncu")}${isMe ? " (sen)" : ""}</div>
        <div class="score-total">${d.total ?? 0} puan</div>
        <div class="score-breakdown muted">
          ${d.cardCount ?? 0} kart
          ${d.mostCards ? " · en çok kart +3" : ""}
          ${d.pisti ? ` · ${d.pisti} pişti +${d.pisti * 10}` : ""}
          ${d.jackCount ? ` · ${d.jackCount} vale +${d.jackCount}` : ""}
          ${d.hasAceSpades ? " · maça ası +1" : ""}
          ${d.hasTwoHearts ? " · kupa 2 +2" : ""}
        </div>
      </div>`;
  }).join("");

  app.innerHTML = `
    <div class="center">
      <div class="emoji">${emoji}</div>
      <div style="font-size:28px;font-weight:800">${title}</div>
      <div class="score-list">${rows}</div>
      <button class="btn-primary" id="rematch" style="max-width:260px">🔁 Tekrar Oyna</button>
      <button class="btn-outline" id="leave" style="max-width:260px">Çık</button>
      <div class="muted">Tekrar Oyna herkesi bekleme odasına döndürür; kurucu yeniden başlatır.</div>
    </div>`;
  document.getElementById("rematch").onclick = rematch;
  document.getElementById("leave").onclick = leaveRoom;
}

async function tryPlay(cardId) {
  const isMyTurn = state.currentTurn === playerId;
  if (!isMyTurn) return toast("Sıra sende değil.");
  playCard(cardId);
}

// ------------------------------------------------------------------
// Yardımcılar
// ------------------------------------------------------------------
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

window.addEventListener("unhandledrejection", (e) => {
  if (connecting) {
    connecting = false;
    lastError = _friendlyError(e.reason || new Error("Beklenmeyen hata"));
    render();
  }
  toast("Hata: " + _friendlyError(e.reason || new Error("bilinmiyor")));
});

// İlk çizim
render();
