// Pişti Online — tarayıcıda çalışan, Firebase Firestore ile gerçek zamanlı
// 2-4 kişilik (herkes kendi başına, takım yok) Pişti oyunu. Klasik 52 kartlık
// standart iskambil destesi kullanılır. Derleme/kurulum gerektirmez;
// GitHub Pages'te barınır.

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js";
import {
  getFirestore, doc as fbDoc, setDoc as fbSetDoc,
  onSnapshot as fbOnSnapshot, runTransaction as fbRunTransaction,
} from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";

// ------------------------------------------------------------------
// Kurulum / kimlik
// ------------------------------------------------------------------
const app = document.getElementById("app");

// Firebase yalnızca online mod için gerekli. Config yoksa online butonları
// devre dışı olur ama "Bilgisayara Karşı" (yerel) mod yine de çalışır.
const cfg = window.FIREBASE_CONFIG;
const FB_READY = !!(cfg && cfg.projectId && cfg.projectId !== "BURAYA_YAPISTIR");
let db = null;
if (FB_READY) {
  const fb = initializeApp(cfg);
  db = getFirestore(fb);
}

const MIN_PLAYERS = 2;
const MAX_PLAYERS = 4;
const ALLOWED_PLAYER_COUNTS = [2, 3, 4];
const MAX_NAME_LENGTH = 12;
const MAX_OPP_CARD_VISUAL = 4; // rakip elinde en fazla bu kadar kart görseli

// Her cihaza kalıcı bir oyuncu kimliği ver (yenilenince kaybolmasın).
const DEVICE_ID = localStorage.getItem("pisti_player") ||
  ((crypto.randomUUID && crypto.randomUUID()) || "p" + Date.now() + Math.random());
localStorage.setItem("pisti_player", DEVICE_ID);
let playerId = DEVICE_ID;   // aktif oynayan kimlik (bot hamlelerinde geçici değişir)
let humanId = DEVICE_ID;    // ekranı gören insan oyuncunun kimliği
let playerName = normalizeName(localStorage.getItem("pisti_name") || "");

function normalizeName(name) {
  return String(name || "").trim().slice(0, MAX_NAME_LENGTH);
}

function nameKey(name) {
  return normalizeName(name).toLocaleLowerCase("tr");
}

// Aynı odada (büyük/küçük harf duyarsız) isim tekrarına izin verme.
function isNameTaken(names, name, exceptId = null) {
  const key = nameKey(name);
  if (!key) return false;
  for (const [id, n] of Object.entries(names || {})) {
    if (exceptId && id === exceptId) continue;
    if (nameKey(n) === key) return true;
  }
  return false;
}

// ------------------------------------------------------------------
// Oyun durumu (yerel)
// ------------------------------------------------------------------
let gameId = null;
let state = null;
let unsub = null;
let lastError = null;
let connecting = false;
let showLocalSetup = false; // "Bilgisayara Karşı" oyuncu sayısı seçim ekranı

// ------------------------------------------------------------------
// Yerel (bilgisayara karşı) mod — Firebase yerine bellek-içi durum
// ------------------------------------------------------------------
let LOCAL = null;
let localCb = null;
let suppressLocalRender = false;
let botTimer = null;
let collectTimer = null;

function isLocal() { return LOCAL !== null; }
function isBot(id) { return typeof id === "string" && id.startsWith("bot"); }
function deepClone(o) { return JSON.parse(JSON.stringify(o)); }
function localSnap() { return { exists: () => LOCAL != null, data: () => deepClone(LOCAL) }; }

function doc(_db, _col, id) { return isLocal() ? { __local: true, id } : fbDoc(_db, _col, id); }

function setDoc(ref, data) {
  if (isLocal()) { LOCAL = deepClone(data); afterLocalWrite(); return Promise.resolve(); }
  return fbSetDoc(ref, data);
}

function onSnapshot(ref, cb) {
  if (isLocal()) { localCb = cb; cb(localSnap()); return () => { localCb = null; }; }
  return fbOnSnapshot(ref, cb);
}

async function runTransaction(_db, fn) {
  if (isLocal()) {
    const tx = {
      get: async () => localSnap(),
      update: (ref, patch) => { LOCAL = Object.assign({}, LOCAL, deepClone(patch)); },
    };
    const r = await fn(tx);
    afterLocalWrite();
    return r;
  }
  return fbRunTransaction(_db, fn);
}

function afterLocalWrite() {
  if (!LOCAL) return;
  if (!suppressLocalRender && localCb) localCb(localSnap());
}

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

// Oyunu kimin başlatacağı (ilk sıra) rastgele seçilir; odayı kuran kişi değil.
function randomPlayer(players) {
  return players[Math.floor(Math.random() * players.length)];
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

// Ekranda soldan sağa sıra yönünde dizim (rakipler veya tüm koltuklar).
function opponentsLeftToRight(players, viewerId) {
  const n = players.length;
  const myIdx = players.indexOf(viewerId);
  if (myIdx === -1) return players.filter((p) => p !== viewerId);
  const out = [];
  for (let i = 1; i < n; i++) out.push(players[nextIndex(myIdx, n, i)]);
  return out;
}

function seatOrderLeftToRight(players, viewerId) {
  const n = players.length;
  const myIdx = players.indexOf(viewerId);
  if (myIdx === -1) return [...players];
  const out = [];
  for (let i = 1; i <= n; i++) out.push(players[nextIndex(myIdx, n, i)]);
  return out;
}

// ------------------------------------------------------------------
// El (round) kurulumu: 4'er kart dağıt + masaya kart aç.
// İlk açılışta masaya kart konur; en üstteki (yüzü açık) kart dışında
// hepsi kapalıdır — 2 ve 4 kişilik oyunda 3 kapalı + 1 açık (4 kart),
// 3 kişilik oyunda 4 kapalı + 1 açık (5 kart).
// Sadece yüzü açık (en üst) kartın vale olmaması sağlanır; kapalı kartlar
// vale/puanlı olabilir ve yakalanınca puanları oyuncuya yazılır.
// ------------------------------------------------------------------
function dealHands(deck, players) {
  const hands = {};
  for (const p of players) hands[p] = deck.splice(deck.length - 4, 4);
  return hands;
}

function dealTable(deck, tableSize) {
  const table = deck.splice(deck.length - tableSize, tableSize);
  // Yüzü açık (en üstteki) kart vale olmasın: valeyse desteyle değiştir.
  let guard = 0;
  while (table.length && table[table.length - 1].rank === "J" && deck.length > 0 && guard++ < 100) {
    const jack = table.pop();
    deck.unshift(jack);       // valeyi destenin dibine göm
    table.push(deck.pop());   // yeni yüzü açık kart al
  }
  return table;
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
  name = normalizeName(name);
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
        pendingCapture: null,
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
  name = normalizeName(name);
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
      const names = g.playerNames || {};
      if (isNameTaken(names, name)) throw new Error("Bu isim zaten alınmış. Başka bir isim seç.");
      players.push(playerId);
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

// Sadece kurucu, 2, 3 ya da 4 oyuncu varken oyunu başlatır.
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
    // 3 kişide masaya 4 kapalı + 1 açık (5 kart); 2 ve 4 kişide 3 kapalı + 1 açık (4 kart).
    const tableSize = players.length === 3 ? 5 : 4;
    const deck = shuffle(buildDeck(numDecks));
    const hands = dealHands(deck, players);
    const pile = dealTable(deck, tableSize);

    const won = {}, pistiCount = {};
    for (const p of players) { won[p] = []; pistiCount[p] = 0; }

    tx.update(ref, {
      hands, drawPile: deck, pile, won, pistiCount,
      lastCapturer: null, lastAction: null, pendingCapture: null,
      currentTurn: randomPlayer(players),
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
    if (g.pendingCapture) return; // masa toplanıyor, yeni hamle yok

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
    const pile = [...pileBefore, card]; // kart her durumda önce masaya konur (görünür)
    const lastAction = { player: playerId, card, captured, isPisti };

    if (captured) {
      const players = g.players;
      const allHandsEmpty = players.every((p) => (hands[p] || []).length === 0);
      const endsGame = allHandsEmpty && (g.drawPile || []).length === 0;
      // Faz A: kart masada görünür kalır; toplama biraz sonra collectPile ile
      // yapılır (oyuncu attığı kartı masada görsün, sonra topluyor).
      tx.update(ref, {
        hands, pile, lastAction,
        pendingCapture: { by: playerId, isPisti, endsGame },
      });
      return;
    }

    // Yakalama yok: sıra ilerler; gerekiyorsa yeni el dağıtılır / oyun biter.
    const won = { ...g.won };
    const pistiCount = { ...g.pistiCount };
    const players = g.players;
    const curIdx = players.indexOf(playerId);
    let finalPile = pile;
    let lastCapturer = g.lastCapturer;
    let drawPile = [...(g.drawPile || [])];
    let status = g.status;
    let winner = null, winners = [], scores = {}, scoreDetail = {};

    const allHandsEmpty = players.every((p) => (hands[p] || []).length === 0);
    if (allHandsEmpty) {
      if (drawPile.length > 0) {
        dealRound(hands, players, drawPile);
      } else {
        // deste bitti, kimsenin eli kalmadı → masada kalanlar son yakalayana
        if (finalPile.length > 0 && lastCapturer) {
          won[lastCapturer] = [...(won[lastCapturer] || []), ...finalPile];
          finalPile = [];
        }
        const result = scoreGame(players, won, pistiCount);
        scores = result.scores; scoreDetail = result.detail; winners = result.winners;
        winner = winners.length === 1 ? winners[0] : null;
        status = "finished";
      }
    }

    const nextTurn = status === "finished" ? g.currentTurn : nextPlayerWithCards(players, hands, curIdx);
    tx.update(ref, {
      hands, pile: finalPile, drawPile, won, pistiCount, lastCapturer, lastAction,
      currentTurn: nextTurn, pendingCapture: null,
      status, winner, winners, scores, scoreDetail,
    });
  });
}

// Faz B: masadaki kartları (attığı kart dahil) yakalayan oyuncuya toplar,
// sırayı ilerletir, gerekiyorsa yeni el dağıtır / oyunu bitirir.
async function collectPile() {
  const ref = doc(db, "pisti_games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (!g.pendingCapture) return;
    const by = g.pendingCapture.by;
    const endsGame = !!g.pendingCapture.endsGame;

    const won = { ...g.won };
    won[by] = [...(won[by] || []), ...(g.pile || [])];
    const pistiCount = { ...g.pistiCount };
    if (g.pendingCapture.isPisti) pistiCount[by] = (pistiCount[by] || 0) + 1;

    const players = g.players;
    const hands = { ...g.hands };
    const curIdx = players.indexOf(by);
    let pile = [];
    let drawPile = [...(g.drawPile || [])];
    let status = g.status;
    let winner = null, winners = [], scores = {}, scoreDetail = {};

    const allHandsEmpty = players.every((p) => (hands[p] || []).length === 0);
    if (allHandsEmpty) {
      if (drawPile.length > 0) {
        dealRound(hands, players, drawPile);
      } else {
        const result = scoreGame(players, won, pistiCount);
        scores = result.scores; scoreDetail = result.detail; winners = result.winners;
        winner = winners.length === 1 ? winners[0] : null;
        status = "finished";
      }
    }

    const nextTurn = status === "finished" ? g.currentTurn : nextPlayerWithCards(players, hands, curIdx);
    tx.update(ref, {
      won, pistiCount, pile, hands, drawPile, lastCapturer: by,
      currentTurn: nextTurn, pendingCapture: null,
      status, winner, winners, scores, scoreDetail,
      skipResultDelay: status === "finished" && endsGame,
    });
  });
}

// Bir el için kart dağıtımı. Normalde herkese 4'er kart. Ama kalan kartlar
// bu eli son yapacaksa ve oyunculara tam bölünüyorsa herkese eşit dağıtılır
// (4 kişilik oyunda son el 5'er kart olur; böylece kimse eksik/fazla almaz).
function dealRound(hands, players, drawPile) {
  const n = players.length;
  const remaining = drawPile.length;
  let per = 4;
  if (remaining <= n * 5 && remaining % n === 0) per = remaining / n;
  for (const p of players) {
    if (drawPile.length === 0) break;
    const take = Math.min(per, drawPile.length);
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
    maybeScheduleCollect();
    scheduleBot();
  });
  render();
}

// Masayı yakalayan varsa (pendingCapture), kısa bir gecikmeyle toplar —
// önce atılan kart masada görünür, sonra toplanır. Oyun bu hamleyle
// bitiyorsa toplam bekleme 2 sn (ayrı sonuç gecikmesi yok).
const COLLECT_DELAY_MS = 1200;
const END_GAME_CAPTURE_DELAY_MS = 2000;

function maybeScheduleCollect() {
  if (collectTimer) return;
  if (!state || state.status !== "playing" || !state.pendingCapture) return;
  if (!(isLocal() || state.pendingCapture.by === humanId)) return;
  const delay = state.pendingCapture.endsGame ? END_GAME_CAPTURE_DELAY_MS : COLLECT_DELAY_MS;
  collectTimer = setTimeout(() => { collectTimer = null; collectPile(); }, delay);
}

function leave() {
  if (unsub) unsub();
  unsub = null;
  if (botTimer) { clearTimeout(botTimer); botTimer = null; }
  if (collectTimer) { clearTimeout(collectTimer); collectTimer = null; }
  resetResultDelay();
  LOCAL = null; localCb = null; suppressLocalRender = false;
  playerId = DEVICE_ID; humanId = DEVICE_ID;
  gameId = null;
  state = null;
  lastError = null;
  render();
}

async function rematch() {
  if (isLocal()) { const n = (state.players || []).length; return startLocalGame(n); }
  const ref = doc(db, "pisti_games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (g.status !== "finished") return;
    tx.update(ref, {
      status: "waiting",
      hands: {}, pile: [], drawPile: [], won: {}, pistiCount: {},
      lastCapturer: null, lastAction: null, pendingCapture: null, currentTurn: "",
      winner: null, winners: [], scores: {}, scoreDetail: {}, skipResultDelay: null,
    });
  });
}

async function leaveRoom() {
  const id = gameId;
  if (!id) return leave();
  if (isLocal()) return leave(); // yerel modda sadece ana ekrana dön
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
// Bilgisayara karşı (yerel) mod
// ------------------------------------------------------------------
function startLocalGame(numPlayers) {
  if (botTimer) { clearTimeout(botTimer); botTimer = null; }
  humanId = "you"; playerId = "you";
  const players = ["you"];
  for (let i = 1; i < numPlayers; i++) players.push("bot" + i);
  const names = { you: playerName || "Sen" };
  for (let i = 1; i < numPlayers; i++) names["bot" + i] = "🤖 Oyuncu " + i;

  const numDecks = numPlayers > 2 ? 2 : 1;
  const tableSize = numPlayers === 3 ? 5 : 4;
  const deck = shuffle(buildDeck(numDecks));
  const hands = dealHands(deck, players);
  const pile = dealTable(deck, tableSize);
  const won = {}, pistiCount = {};
  for (const p of players) { won[p] = []; pistiCount[p] = 0; }

  LOCAL = {
    status: "playing", players, playerNames: names, hands, pile, drawPile: deck,
    won, pistiCount, lastCapturer: null, lastAction: null, pendingCapture: null,
    currentTurn: randomPlayer(players),
    winner: null, winners: [], scores: {}, scoreDetail: {}, local: true, createdAt: Date.now(),
  };
  showLocalSetup = false;
  gameId = "🤖 Bilgisayara Karşı";
  connecting = false;
  subscribe(gameId);
}

// Bot kart seçimi: önce (mümkünse pişti yapan) sayı eşleşmesiyle yak; masada
// birden fazla kart varken vale ile süpür; aksi halde en değersiz kartı at.
function pistiBotChoose(g, botId) {
  const hand = g.hands[botId] || [];
  const pile = g.pile || [];
  const top = pile[pile.length - 1];

  const matches = hand.filter((c) => c.rank !== "J" && pile.length > 0 && top && top.rank === c.rank);
  if (matches.length) return matches[0].id; // yakala (masada tek kart varsa pişti)

  const jacks = hand.filter((c) => c.rank === "J");
  if (jacks.length && pile.length >= 2) return jacks[0].id; // çok kartı vale ile süpür

  const nonJacks = hand.filter((c) => c.rank !== "J");
  if (nonJacks.length === 0) return jacks[0].id; // elde sadece vale kaldıysa mecbur

  // Yakalama yok: rakibe puan vermemek için en değersiz kartı at (vale sakla).
  const valueOf = (c) => {
    if (c.rank === "A") return 3;
    if (c.suit === "C" && c.rank === "2") return 4;
    if (c.suit === "D" && c.rank === "10") return 5;
    return 1;
  };
  const sorted = [...nonJacks].sort((a, b) => valueOf(a) - valueOf(b));
  return sorted[0].id;
}

function scheduleBot() {
  if (botTimer) { clearTimeout(botTimer); botTimer = null; }
  if (!isLocal() || !LOCAL || LOCAL.status !== "playing") return;
  if (LOCAL.pendingCapture) return; // masa toplanana kadar bot beklesin
  const cur = LOCAL.currentTurn;
  if (!isBot(cur)) return;
  botTimer = setTimeout(() => { botTimer = null; runBotMove(cur); }, 2000);
}

async function runBotMove(botId) {
  if (!isLocal() || !LOCAL || LOCAL.status !== "playing" || LOCAL.currentTurn !== botId) return;
  suppressLocalRender = true;
  playerId = botId;
  try {
    const cardId = pistiBotChoose(LOCAL, botId);
    if (cardId) await playCard(cardId);
  } finally {
    playerId = humanId;
    suppressLocalRender = false;
  }
  if (localCb) localCb(localSnap()); // render + sonraki sıra
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

// Oyun bitince son hamle görülsün diye sonuç ekranına geçmeden önce
// 2 saniye tahtayı göstermeye devam ederiz (yakalama ile bitişte
// bu süre toplama beklemesine dahildir).
const RESULT_DELAY_MS = 2000;
let resultDelayTimer = null;
let showResult = false;

function resetResultDelay() {
  if (resultDelayTimer) { clearTimeout(resultDelayTimer); resultDelayTimer = null; }
  showResult = false;
}

function render() {
  if (connecting) return renderConnecting();
  if (!gameId) return showLocalSetup ? renderLocalSetup() : renderHome();
  if (!state) return renderLoading();
  if (state.status === "waiting") { resetResultDelay(); return renderLobby(); }
  if (state.status === "finished") {
    if (!showResult) {
      const delay = state.skipResultDelay ? 0 : RESULT_DELAY_MS;
      if (delay === 0) {
        showResult = true;
        return renderResult();
      }
      if (!resultDelayTimer) {
        resultDelayTimer = setTimeout(() => {
          resultDelayTimer = null;
          showResult = true;
          render();
        }, delay);
      }
      return renderBoard();
    }
    return renderResult();
  }
  resetResultDelay();
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
      <input id="name" placeholder="Adınız / Nickname" maxlength="${MAX_NAME_LENGTH}" value="${escapeHtml(playerName)}" />
      <button class="btn-primary" id="vscpu" style="width:100%;background:#1565c0">🤖 Bilgisayara Karşı Oyna</button>
      <div class="divider"></div>
      <button class="btn-primary" id="create" ${FB_READY ? "" : "disabled style='opacity:.5'"}>Yeni Oyun Kur</button>
      <input id="code" placeholder="Oda Kodu (örn. K7P2M)" style="text-transform:uppercase" />
      <button class="btn-outline" id="join" ${FB_READY ? "" : "disabled style='opacity:.5'"}>Oyuna Katıl</button>
      <div class="muted">${FB_READY ? "Online ya da bilgisayara karşı · 2 veya 4 kişi · takım yok" : "Online için Firebase ayarı gerekli (README). Bilgisayara karşı yine oynanır."}</div>
      ${lastError ? `<div class="error">${escapeHtml(lastError)}</div>` : ""}
      <button class="btn-outline" id="back-to-select">← Oyun Seç</button>
    </div>`;

  document.getElementById("back-to-select").onclick = () => {
    window.location.href = "../";
  };

  const nameEl = document.getElementById("name");
  const codeEl = document.getElementById("code");
  const saveName = () => {
    playerName = normalizeName(nameEl.value);
    nameEl.value = playerName;
    localStorage.setItem("pisti_name", playerName);
  };

  document.getElementById("vscpu").onclick = () => {
    saveName();
    if (!playerName) return toast("Önce bir isim gir.");
    showLocalSetup = true;
    render();
  };
  document.getElementById("create").onclick = () => {
    saveName();
    if (!FB_READY) return toast("Online oyun için Firebase ayarı gerekli.");
    if (!playerName) return toast("Önce bir isim gir.");
    createGame(playerName);
  };
  document.getElementById("join").onclick = () => {
    saveName();
    if (!FB_READY) return toast("Online oyun için Firebase ayarı gerekli.");
    if (!playerName) return toast("Önce bir isim gir.");
    const code = codeEl.value.trim().toUpperCase();
    if (!code) return toast("Oda kodunu gir.");
    joinGame(code, playerName);
  };
}

// "Bilgisayara Karşı" — 2, 3 ya da 4 kişi seçim ekranı.
function renderLocalSetup() {
  app.innerHTML = `
    <div class="center">
      <div>
        <div class="logo" style="font-size:44px">🤖</div>
        <div style="font-size:20px;font-weight:800;margin-top:8px">Bilgisayara Karşı</div>
      </div>
      <div class="muted">Kaç kişi olsun? (sen + bilgisayarlar)</div>
      <div style="display:flex;flex-direction:column;gap:12px;width:100%;max-width:260px">
        <button class="btn-primary" data-n="2">2 Oyuncu (sen + 1 bot)</button>
        <button class="btn-primary" data-n="3">3 Oyuncu (sen + 2 bot)</button>
        <button class="btn-primary" data-n="4">4 Oyuncu (sen + 3 bot)</button>
      </div>
      <div class="muted">Pişti 2, 3 ya da 4 kişiyle oynanır.</div>
      <button class="btn-outline" id="back" style="max-width:200px">Geri</button>
    </div>`;
  app.querySelectorAll("button[data-n]").forEach((b) => {
    b.onclick = () => startLocalGame(parseInt(b.getAttribute("data-n"), 10));
  });
  document.getElementById("back").onclick = () => { showLocalSetup = false; render(); };
}

function renderLoading() {
  app.innerHTML = `<div class="center"><div class="spinner"></div>
    <div class="muted">Bağlanılıyor...</div>
    <button class="btn-outline" id="back" style="max-width:200px">Geri</button></div>`;
  document.getElementById("back").onclick = leave;
}

function renderLobby() {
  const players = seatOrderLeftToRight(state.players || [], playerId);
  const isHost = (state.players || [])[0] === playerId;
  const rows = players.map((p) => {
    const tags = [(state.players || [])[0] === p ? "kurucu" : "", p === playerId ? "sen" : ""].filter(Boolean).join(" · ");
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
  if (startBtn) startBtn.onclick = () => { if (ALLOWED_PLAYER_COUNTS.includes(state.players.length)) startGame(); };
}

// Kart adını Türkçe yaz: "Karo 7", "Maça Vale", "Kupa As" ...
function rankName(r) { return ({ A: "As", J: "Vale", Q: "Kız", K: "Papaz" })[r] || r; }
function cardName(c) { return `${SUIT_NAME[c.suit]} ${rankName(c.rank)}`; }

// Masadaki desteyi göster: en üstteki kart açık, altındakiler kapalı yığın.
function tableStackHtml(pile) {
  const top = pile[pile.length - 1];
  const hidden = pile.length - 1;
  if (hidden <= 0) return cardHtml(top, { big: true });

  const behind = hidden === 1
    ? `<span class="stack-behind s1">${cardHtml(null, { faceDown: true, big: true })}</span>`
    : `<span class="stack-behind s2">${cardHtml(null, { faceDown: true, big: true })}</span>
       <span class="stack-behind s1">${cardHtml(null, { faceDown: true, big: true })}</span>`;

  return `<div class="table-stack">
    ${behind}
    <span class="stack-top">${cardHtml(top, { big: true })}</span>
  </div>`;
}

function renderBoard() {
  const players = state.players;
  const collecting = !!state.pendingCapture; // masa toplanıyor (kısa bekleme)
  const isMyTurn = state.currentTurn === playerId && !collecting;
  const myHand = state.hands[playerId] || [];
  const pile = state.pile || [];
  const top = pile[pile.length - 1];
  const deckCount = (state.drawPile || []).length;

  const pistiCount = state.pistiCount || {};
  const others = opponentsLeftToRight(players, playerId);
  const oppHtml = others.map((p) => {
    const count = (state.hands[p] || []).length;
    const wonCount = (state.won[p] || []).length;
    const pisti = pistiCount[p] || 0;
    const isTurn = state.currentTurn === p;
    return `
      <div class="opp ${isTurn ? "opp-turn" : ""}">
        <div class="opp-name">${escapeHtml(state.playerNames[p] || "Oyuncu")}</div>
        <div class="opp-cards">${
          Array.from({ length: Math.min(count, 4) }, () => cardHtml(null, { faceDown: true, small: true })).join("")
        }</div>
        <div class="opp-score">${wonCount}</div>
        ${pisti > 0 ? `<div class="pisti-tag">🔥 ${pisti} pişti</div>` : ""}
      </div>`;
  }).join("");

  const myWon = (state.won[playerId] || []).length;
  const myPisti = pistiCount[playerId] || 0;
  const lastAction = state.lastAction;
  const lastActionHtml = lastAction
    ? (lastAction.isPisti
        ? `<div class="last-action pisti-banner">🎉 ${escapeHtml(state.playerNames[lastAction.player] || "Oyuncu")} PİŞTİ yaptı! (${cardName(lastAction.card)})</div>`
        : `<div class="last-action">${escapeHtml(state.playerNames[lastAction.player] || "Oyuncu")}
            <b>${cardName(lastAction.card)}</b> oynadı${lastAction.captured ? " — yaktı! 🔥" : ""}</div>`)
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
          <small>Yerdeki kartlar</small>
          ${top ? tableStackHtml(pile) : `<div class="empty-slot">boş</div>`}
          <div class="pile-count">${pile.length} kart</div>
        </div>
        <div class="pile">
          <small>Sende</small>
          <div class="mini-stat">${myWon} 🂠</div>
          ${myPisti > 0 ? `<div class="pisti-tag">🔥 ${myPisti} pişti</div>` : ""}
        </div>
      </div>

      ${lastActionHtml}

      <div class="turn ${isMyTurn ? "mine" : "theirs"}">
        ${collecting
          ? "🧹 " + escapeHtml(state.playerNames[state.pendingCapture.by] || "Oyuncu") + " masayı topluyor..."
          : (isMyTurn ? "● Sıra sende — bir kart oyna" : "○ Sıra: " + escapeHtml(state.playerNames[state.currentTurn] || "Oyuncu"))}
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
  if (state.pendingCapture) return; // masa toplanıyor, kısa bir an bekle
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

// ------------------------------------------------------------------
// Telefon "geri" tuşu: oyundayken direkt çıkmasın, onay sorsun.
// Ana ekrandaysan normal geri (uygulamadan çıkış) çalışır.
// ------------------------------------------------------------------
history.pushState({ app: true }, "");
window.addEventListener("popstate", () => {
  if (gameId) {
    history.pushState({ app: true }, ""); // onaylanmadıkça kal
    if (confirm("Oyundan çıkmak istediğinize emin misiniz?")) leaveRoom();
    return;
  }
  if (showLocalSetup) {
    history.pushState({ app: true }, "");
    showLocalSetup = false; render();
    return;
  }
  // Ana ekran: geri tuşu normal çalışsın.
});

// İlk çizim
render();
