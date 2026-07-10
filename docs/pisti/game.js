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
// 3 kişiyle 2 deste (104 kart) tam bölünmüyor; bu yüzden sadece 2 ya da 4
// kişilik oyuna izin verilir (3 kişi bekleme odasında kalabilir ama başlatılamaz).
const ALLOWED_PLAYER_COUNTS = [2, 4];

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

// 2 oyuncuda tek 52'lik deste, 2'den fazla oyuncuda iki deste (104 kart) birleştirilir.
function buildDeck(numDecks = 1) {
  const deck = [];
  for (let n = 0; n < numDecks; n++) {
    for (const suit of SUITS) {
      for (const rank of RANKS) deck.push({ suit, rank, id: uid() });
    }
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

// Sadece kurucu, 2 ya da 4 oyuncu varken oyunu başlatır (3 kişi desteklenmez).
async function startGame() {
  const ref = doc(db, "pisti_games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (g.status !== "waiting") return;
    const players = g.players || [];
    if (players[0] !== playerId) return; // sadece kurucu
    if (!ALLOWED_PLAYER_COUNTS.includes(players.length)) return;

    const numDecks = players.length > 2 ? 2 : 1;
    const deck = shuffle(buildDeck(numDecks));
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
    const aceCount = cards.filter((c) => c.rank === "A").length;
    const clubTwoCount = cards.filter((c) => c.suit === "C" && c.rank === "2").length;
    const diamondTenCount = cards.filter((c) => c.suit === "D" && c.rank === "10").length;
    const mostCards = cardCounts[p] === maxCards && maxCards > 0;
    const pisti = pistiCount[p] || 0;
    const total = pisti * 10 + jackCount * 1 + aceCount * 1 + clubTwoCount * 2 + diamondTenCount * 3 + (mostCards ? 3 : 0);
    detail[p] = { cardCount: cardCounts[p], jackCount, aceCount, clubTwoCount, diamondTenCount, mostCards, pisti, total };
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

    const allHandsEmpty = players.every((p) => (hands[p] || []).length === 0);
    let drawPile = [...(g.drawPile || [])];
    let status = g.status;
    let winner = null, winners = [], scores = {}, scoreDetail = {};

    if (allHandsEmpty) {
      if (drawPile.length > 0) {
        // Yeni el: herkese 4'er kart daha dağıt (masa aynen kalır). 2 desteli
        // (3-4 kişilik) oyunlarda kalan kart sayısı oyuncu*4'e tam
        // bölünmeyebilir; bu yüzden mümkün olduğunca 4'er dağıtılır, deste
        // biterse sıradaki oyuncu(lar) bu turda kart alamayabilir.
        dealRound(hands, players, drawPile);
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

    // Sıra, eli boş olmayan bir sonraki oyuncuya geçer (eşit olmayan
    // dağıtım durumunda eli hâlâ boş olan oyuncular atlanır).
    const nextTurn = status === "finished" ? g.currentTurn : nextPlayerWithCards(players, hands, curIdx);

    tx.update(ref, {
      hands, pile, drawPile, won, pistiCount, lastCapturer, lastAction,
      currentTurn: nextTurn,
      status, winner, winners, scores, scoreDetail,
    });
  });
}

function dealRound(hands, players, drawPile) {
  for (const p of players) {
    if (drawPile.length === 0) break;
    const take = Math.min(4, drawPile.length);
    hands[p] = drawPile.splice(drawPile.length - take, take);
  }
}

function nextPlayerWithCards(players, hands, fromIdx) {
  const n = players.length;
  for (let step = 1; step <= n; step++) {
    const idx = nextIndex(fromIdx, n, step);
    if ((hands[players[idx]] || []).length > 0) return players[idx];
  }
  return null;
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
          // Sırası olan çıktıysa sırayı elinde kartı olan bir sonraki oyuncuya ver.
          const old = g.players;
          const curIdx = old.indexOf(playerId);
          let afterPlayer = null;
          for (let step = 1; step <= old.length; step++) {
            const candidate = old[nextIndex(curIdx, old.length, step)];
            if (candidate === playerId) continue;
            if ((hands[candidate] || []).length > 0) { afterPlayer = candidate; break; }
          }
          updates.currentTurn = afterPlayer || players[0];
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

  // Resimli kartlar (Vale/Kız/Papaz) klasik figürlü görünüm alır; Vale ayrıca
  // altın çerçeveyle vurgulanır (Pişti'de yanlışlıkla oynanmasın diye).
  const isFace = card.rank === "J" || card.rank === "Q" || card.rank === "K";
  const jackCls = card.rank === "J" ? " jack" : "";
  const center = isFace
    ? `<span class="court">${courtArt(card.rank)}</span>`
    : `<span class="center-pip"><span class="suit-big">${sym}</span></span>`;

  return `<div class="card face ${cls}${jackCls}${dimCls}" style="${sv}"${click}>
      <span class="corner tl">${card.rank}<br/>${sym}</span>
      ${center}
      <span class="corner br">${card.rank}<br/>${sym}</span>
    </div>`;
}

// Klasik "figürlü kart" çizimi (üstte ve altta simetrik). J/Q/K için ortak
// figür; sadece taçtaki mücevher rengi rütbeye göre değişir. Kart rengini
// (kırmızı/siyah) köşe indeksleri belirtir.
function courtArt(rank) {
  const gem = rank === "K" ? "#c62828" : rank === "Q" ? "#1565c0" : "#2e7d32";
  const half = `
    <g stroke="#1a1a1a" stroke-width="1.4" stroke-linejoin="round" stroke-linecap="round">
      <path d="M34 33 L38 22 L44 30 L50 20 L56 30 L62 22 L66 33 Z" fill="#f4c430"/>
      <circle cx="38" cy="22" r="1.8" fill="${gem}"/>
      <circle cx="50" cy="20" r="1.8" fill="${gem}"/>
      <circle cx="62" cy="22" r="1.8" fill="${gem}"/>
      <rect x="34" y="33" width="32" height="5" fill="#c62828"/>
      <ellipse cx="50" cy="46" rx="8.5" ry="9.5" fill="#f6d7b8"/>
      <path d="M41.5 44 h4 M54.5 44 h4" stroke="#1a1a1a" stroke-width="1.2"/>
      <path d="M47 50 q3 2 6 0" fill="none" stroke="#1a1a1a" stroke-width="1.2"/>
      <path d="M33 74 Q33 55 50 55 Q67 55 67 74 Z" fill="#c62828"/>
      <path d="M45 55 L50 63 L55 55 Z" fill="#f4c430"/>
      <path d="M50 63 V74" stroke="#f4c430" stroke-width="2"/>
    </g>`;
  return `<svg viewBox="0 0 100 150" preserveAspectRatio="xMidYMid meet">
    <rect x="5" y="5" width="90" height="140" rx="7" fill="#fffdf5" stroke="#c9a227" stroke-width="1.6"/>
    <line x1="12" y1="75" x2="88" y2="75" stroke="#c9a227" stroke-width="1" stroke-dasharray="3 2.5"/>
    ${half}
    <g transform="rotate(180 50 75)">${half}</g>
  </svg>`;
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
        ? `<button class="btn-primary" id="start" ${!ALLOWED_PLAYER_COUNTS.includes(players.length) ? "disabled style='opacity:.5'" : ""}>
             Oyunu Başlat
           </button>
           ${players.length < MIN_PLAYERS ? `<div class="muted">En az 2 oyuncu gerekiyor</div>` : ""}
           ${players.length === 3 ? `<div class="muted">3 kişiyle oynanamaz — 2 kişiyle ya da 4. kişiyi bekleyerek 4 kişiyle başlat</div>` : ""}`
        : `<div class="muted">Kurucu başlatınca oyun başlayacak...</div><div class="spinner"></div>`}

      <button class="btn-outline" id="back" style="max-width:200px">Çık</button>
    </div>`;

  document.getElementById("codebox").onclick = () => {
    navigator.clipboard && navigator.clipboard.writeText(gameId);
    document.getElementById("copied").textContent = "Kopyalandı ✓";
  };
  document.getElementById("back").onclick = leaveRoom;
  const startBtn = document.getElementById("start");
  if (startBtn) startBtn.onclick = () => { if (ALLOWED_PLAYER_COUNTS.includes(state.players.length)) startGame(); };
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
          ${d.aceCount ? ` · ${d.aceCount} as +${d.aceCount}` : ""}
          ${d.clubTwoCount ? ` · sinek 2 +${d.clubTwoCount * 2}` : ""}
          ${d.diamondTenCount ? ` · karo 10 +${d.diamondTenCount * 3}` : ""}
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
