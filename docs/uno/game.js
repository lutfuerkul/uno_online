// UNO Online — tarayıcıda çalışan, Firebase Firestore ile gerçek zamanlı
// 2-4 kişilik UNO oyunu. Derleme/kurulum gerektirmez; GitHub Pages'te barınır.

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

const MAX_PLAYERS = 4;
const MAX_NAME_LENGTH = 8;
const MAX_OPP_CARD_VISUAL = 4; // rakip elinde en fazla bu kadar kart görseli

// Her cihaza kalıcı bir oyuncu kimliği ver (yenilenince kaybolmasın).
const DEVICE_ID = localStorage.getItem("uno_player") ||
  ((crypto.randomUUID && crypto.randomUUID()) || "p" + Date.now() + Math.random());
localStorage.setItem("uno_player", DEVICE_ID);
let playerId = DEVICE_ID;   // aktif oynayan kimlik (bot hamlelerinde geçici değişir)
let humanId = DEVICE_ID;    // ekranı gören insan oyuncunun kimliği
let playerName = normalizeName(localStorage.getItem("uno_name") || "");

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
// Yerel (bilgisayara karşı) mod — Firebase yerine bellek-içi durum
// ------------------------------------------------------------------
const LOCAL_COLLECTION = "games";
let LOCAL = null;              // yerel oyun durumu (Firestore belgesinin karşılığı) ya da null
let localCb = null;           // yerel "onSnapshot" dinleyicisi
let suppressLocalRender = false; // bot hamlesi sırasında ara render'ları bastır
let botTimer = null;

function isLocal() { return LOCAL !== null; }
function isBot(id) { return typeof id === "string" && id.startsWith("bot"); }
function deepClone(o) { return JSON.parse(JSON.stringify(o)); }
function localSnap() { return { exists: () => LOCAL != null, data: () => deepClone(LOCAL) }; }

// --- Firebase / yerel dağıtıcılar: mevcut aksiyon fonksiyonları ikisiyle de çalışır ---
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

// Her yerel yazımdan sonra dinleyiciyi (bastırılmadıysa) tetikler.
function afterLocalWrite() {
  if (!LOCAL) return;
  if (!suppressLocalRender && localCb) localCb(localSnap());
}

// ------------------------------------------------------------------
// Oyun durumu (yerel)
// ------------------------------------------------------------------
let gameId = null;
let state = null;
let unsub = null;
let lastError = null;
let connecting = false; // oda kuruluyor/katılınıyor (spinner göster)
let showLocalSetup = false; // "Bilgisayara Karşı" oyuncu sayısı seçim ekranı

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

// Oyunu kimin başlatacağı (ilk sıra) rastgele seçilir; odayı kuran kişi değil.
function randomPlayer(players) {
  return players[Math.floor(Math.random() * players.length)];
}

function isWild(c) {
  return c.type === "wild" || c.type === "wildDrawFour";
}

// Reverse kilidi varken oynanabilir: aynı renk, başka reverse, +2, Joker ya da +4.
function canPlayUnderReverseLock(card, reverseColor) {
  return card.type === "reverse" || card.type === "drawTwo" || card.color === reverseColor || isWild(card);
}

function canPlay(card, top, currentColor) {
  if (isWild(card)) return true;
  if (card.color === currentColor) return true;
  if (card.type === "number" && top.type === "number") return card.value === top.value;
  if (card.type === top.type && card.type !== "number") return true;
  return false;
}

// Sıradaki oyuncunun index'i (yönü ve adım sayısını dikkate alır).
function nextIndex(idx, dir, n, steps = 1) {
  return (((idx + dir * steps) % n) + n) % n;
}

// Sırayı, bloklu oyuncuları atlayarak ilerletir. Birden fazla bağımsız blok
// olabilir; her bloklu oyuncu sırası gelince bir blok tüketilerek atlanır.
// (Örn. ben Veli'yi, Ali de beni bloklarsa; Ali'den sonra hem Veli hem ben
//  atlanır, bloklarımız ayrı ayrı tüketilir.)
function advanceTurn(players, curIdx, dir, blocked) {
  const n = players.length;
  const blk = [...(blocked || [])];
  let idx = nextIndex(curIdx, dir, n, 1);
  let guard = 0;
  while (guard++ < n * 4) {
    const bi = blk.indexOf(players[idx]);
    if (bi === -1) break;          // bloklu değil → sıradaki oyuncu bu
    blk.splice(bi, 1);             // bir blok tüket
    idx = nextIndex(idx, dir, n, 1);
  }
  return { nextTurn: players[idx], blocked: blk };
}

// Ekranda soldan sağa sıra yönünde dizim (rakipler veya tüm koltuklar).
function opponentsLeftToRight(players, viewerId, dir = 1) {
  const n = players.length;
  const myIdx = players.indexOf(viewerId);
  if (myIdx === -1) return players.filter((p) => p !== viewerId);
  const out = [];
  for (let i = 1; i < n; i++) out.push(players[nextIndex(myIdx, dir, n, i)]);
  return out;
}

function seatOrderLeftToRight(players, viewerId, dir = 1) {
  const n = players.length;
  const myIdx = players.indexOf(viewerId);
  if (myIdx === -1) return [...players];
  const out = [];
  for (let i = 1; i <= n; i++) out.push(players[nextIndex(myIdx, dir, n, i)]);
  return out;
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
// Bir sözü zaman aşımına karşı sarmalar (bağlantı takılırsa kullanıcıya haber ver).
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
      setDoc(doc(db, "games", code), {
        status: "waiting", // waiting -> playing -> finished
        players: [playerId], // players[0] = kurucu (host)
        playerNames: { [playerId]: name },
        hands: {},
        drawPile: [],
        discardPile: [],
        currentColor: "red",
        currentTurn: "",
        direction: 1,
        hasDrawn: false,
        unoSafe: [],
        reverseColor: null,
        blockedPlayers: [],
        winner: null,
        lastAction: null,
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

// Hata mesajını kullanıcı dostu hale getirir.
function _friendlyError(e) {
  return (e && e.message ? e.message : String(e)).replace(/^Error:\s*/, "");
}

async function joinGame(code, name) {
  name = normalizeName(name);
  lastError = null;
  connecting = true;
  render();
  const ref = doc(db, "games", code);
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
      currentTurn: randomPlayer(players),
      direction: 1,
      hasDrawn: false,
      unoSafe: [],
      reverseColor: null,
      blockedPlayers: [],
      lastAction: null,
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
    const finisher = hand.length === 1; // son kart — renk/hedef seçimi ve ceza yok

    // Reverse sonrası özel kısıt: aynı renk, başka reverse, +2, Joker ya da +4.
    const inReverse = g.reverseColor != null;
    if (inReverse) {
      if (!canPlayUnderReverseLock(card, g.reverseColor)) return;
      if (isWild(card) && !chosenColor && !finisher) return;
    } else {
      if (!canPlay(card, top, g.currentColor)) return;
      if (isWild(card) && !chosenColor && !finisher) return;
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
    const newColor = isWild(card) ? (chosenColor || g.currentColor) : card.color;

    // Kart etkisine göre sırayı hesapla.
    const newDir = dir; // (bu varyantta reverse yön çevirmiyor)
    const pickTarget = () => (targetId && players.includes(targetId) && targetId !== playerId)
      ? targetId : players[nextIndex(curIdx, dir, n, 1)];
    let keepTurn = false; // reverse: atan tekrar oynar
    let nextReverseColor = null; // reverse comboyu sürdürür/başlatır
    let blocked = [...(g.blockedPlayers || [])]; // bekleyen bloklar (birikir)
    let effectTarget = null; // gösterim: kimi blokladı / kime kart çektirdi
    if (!finisher) {
      if (card.type === "skip") {
        effectTarget = pickTarget();
        blocked.push(effectTarget); // o oyuncu bir kez sıra atlar (blok birikir)
      } else if (card.type === "reverse") {
        keepTurn = true;
        nextReverseColor = card.color; // sonraki hamle bu renge/reverse'e kilitli
      } else if (card.type === "drawTwo") {
        effectTarget = pickTarget();
        drawInto(hands, effectTarget, draw, discard, 2);
      } else if (card.type === "wildDrawFour") {
        effectTarget = pickTarget();
        drawInto(hands, effectTarget, draw, discard, 4);
      }
    }

    // Sırayı ilerlet; bloklu oyuncular denk geldikçe atlanır (bloklar tükenir).
    let nextTurn, finalBlocked;
    if (keepTurn) {
      nextTurn = playerId;
      finalBlocked = blocked;
    } else {
      const adv = advanceTurn(players, curIdx, newDir, blocked);
      nextTurn = adv.nextTurn;
      finalBlocked = adv.blocked;
    }

    let status = g.status;
    let winner = g.winner;
    if (hand.length === 0) {
      status = "finished";
      winner = playerId;
    }

    // Kart oynandı → yeni oyuncunun turu, çekim sıfırlanır.
    const lastAction = { player: playerId, cardType: card.type, cardColor: newColor,
      cardValue: card.value, target: effectTarget };

    tx.update(ref, {
      hands, drawPile: draw, discardPile: discard,
      currentColor: newColor, currentTurn: nextTurn, direction: newDir,
      hasDrawn: false, reverseColor: nextReverseColor, blockedPlayers: finalBlocked,
      lastAction, status, winner,
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

    tx.update(ref, { hands, drawPile: draw, discardPile: discard, hasDrawn: true });
  });
  maybeEndStalemate();
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

    // Sırayı ilerlet; bloklu oyuncular denk geldikçe atlanır (bloklar tükenir).
    const adv = advanceTurn(players, curIdx, dir, g.blockedPlayers || []);
    const nextTurn = adv.nextTurn;

    const draw = [...g.drawPile];
    const discard = [...g.discardPile];
    const hands = { ...g.hands };

    tx.update(ref, {
      currentTurn: nextTurn, hasDrawn: false, reverseColor: null,
      blockedPlayers: adv.blocked, hands, drawPile: draw, discardPile: discard,
      lastAction: { player: playerId, cardType: "pass" },
    });
  });
  maybeEndStalemate();
}

function subscribe(code) {
  gameId = code;
  if (unsub) unsub();
  unsub = onSnapshot(doc(db, "games", code), (snap) => {
    state = snap.exists() ? snap.data() : null;
    render();
    maybeEndStalemate();
    scheduleBot();
  });
  render();
}

function leave() {
  if (unsub) unsub();
  unsub = null;
  if (botTimer) { clearTimeout(botTimer); botTimer = null; }
  LOCAL = null; localCb = null; suppressLocalRender = false;
  playerId = DEVICE_ID; humanId = DEVICE_ID;
  gameId = null;
  state = null;
  lastError = null;
  render();
}

// Oyunu aynı oyuncularla yeniden başlatmak için bekleme odasına döndürür.
async function rematch() {
  if (isLocal()) { const n = (state.players || []).length; return startLocalGame(n); }
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
      blockedPlayers: [],
      winner: null,
      lastAction: null,
    });
  });
}

// Oyuncuyu odadan çıkarır (diğerleri devam edebilsin diye durumu düzeltir).
async function leaveRoom() {
  const id = gameId;
  if (!id) return leave();
  if (isLocal()) return leave(); // yerel modda sadece ana ekrana dön
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
      const updates = { players, playerNames: names, hands };

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
// Bilgisayara karşı (yerel) mod
// ------------------------------------------------------------------
function startLocalGame(numPlayers) {
  if (botTimer) { clearTimeout(botTimer); botTimer = null; }
  humanId = "you"; playerId = "you";
  const players = ["you"];
  for (let i = 1; i < numPlayers; i++) players.push("bot" + i);
  const names = { you: playerName || "Sen" };
  for (let i = 1; i < numPlayers; i++) names["bot" + i] = "🤖 Oyuncu " + i;

  const deck = shuffle(buildDeck());
  const hands = {};
  for (const p of players) hands[p] = Array.from({ length: 7 }, () => deck.pop());
  let first = deck.pop();
  while (first.type !== "number") { deck.unshift(first); first = deck.pop(); }

  LOCAL = {
    status: "playing", players, playerNames: names,
    hands, drawPile: deck, discardPile: [first],
    currentColor: first.color, currentTurn: randomPlayer(players), direction: 1,
    hasDrawn: false, unoSafe: [], reverseColor: null, blockedPlayers: [],
    winner: null, lastAction: null, local: true, createdAt: Date.now(),
  };
  showLocalSetup = false;
  gameId = "🤖 Bilgisayara Karşı";
  connecting = false;
  subscribe(gameId);
}

// Oynanabilir kartlar (reverse kilidi dikkate alınır).
function unoPlayable(hand, g) {
  const top = g.discardPile[g.discardPile.length - 1];
  const reverseColor = g.reverseColor || null;
  return hand.filter((c) => reverseColor != null
    ? canPlayUnderReverseLock(c, reverseColor)
    : canPlay(c, top, g.currentColor));
}

function canDrawFromPiles(draw, discard) {
  return draw.length > 0 || discard.length > 1;
}

// Çekilecek kart kalmadı ve kimse oynayamıyorsa oyun kilitlenmiştir.
function isGameDeadlocked(g) {
  if (!g || g.status !== "playing") return false;
  const draw = g.drawPile || [];
  const discard = g.discardPile || [];
  const top = discard[discard.length - 1];
  const players = g.players || [];
  const n = players.length;
  const dir = g.direction || 1;
  const curIdx = players.indexOf(g.currentTurn);
  if (curIdx === -1 || !top) return false;

  const canDraw = canDrawFromPiles(draw, discard);

  function handHasPlay(hand, reverseColor) {
    if (reverseColor != null) {
      return hand.some((c) => canPlayUnderReverseLock(c, reverseColor));
    }
    return hand.some((c) => canPlay(c, top, g.currentColor));
  }

  for (let step = 0; step < n; step++) {
    const pid = players[nextIndex(curIdx, dir, n, step)];
    const hand = g.hands[pid] || [];
    const reverseColor = step === 0 ? (g.reverseColor || null) : null;

    if (handHasPlay(hand, reverseColor)) return false;

    if (step === 0) {
      if (!g.hasDrawn && canDraw) return false;
      if (!g.hasDrawn && !canDraw) return true;
    } else if (canDraw) {
      return false;
    }
  }
  return true;
}

async function endGameStalemate() {
  if (isLocal()) {
    if (!LOCAL || LOCAL.status !== "playing" || !isGameDeadlocked(LOCAL)) return;
    LOCAL = {
      ...LOCAL,
      status: "finished",
      winner: null,
      lastAction: { player: LOCAL.currentTurn, cardType: "stalemate" },
    };
    afterLocalWrite();
    return;
  }
  if (!gameId || !db) return;
  const ref = doc(db, "games", gameId);
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    const g = snap.data();
    if (g.status !== "playing" || !isGameDeadlocked(g)) return;
    tx.update(ref, {
      status: "finished",
      winner: null,
      lastAction: { player: g.currentTurn, cardType: "stalemate" },
    });
  });
}

function maybeEndStalemate() {
  if (!state || state.status !== "playing") return;
  if (!isGameDeadlocked(state)) return;
  endGameStalemate().catch(() => {});
}

function botPickCard(cands, g, botId) {
  const opps = g.players.filter((p) => p !== botId);
  const threat = Math.min(...opps.map((p) => (g.hands[p] || []).length));
  const score = (c) => {
    if (c.type === "number") return 1;
    if (c.type === "reverse") return 2;
    if (c.type === "skip" || c.type === "drawTwo") return threat <= 2 ? 5 : 2;
    if (c.type === "wildDrawFour") return threat <= 2 ? 4 : 0; // +4'ü baskı yokken sakla
    if (c.type === "wild") return 0; // jokeri sakla
    return 1;
  };
  return [...cands].sort((a, b) => score(b) - score(a))[0];
}

function botPickColor(hand) {
  const counts = { red: 0, yellow: 0, green: 0, blue: 0 };
  for (const c of hand) if (c.color && c.color !== "wild") counts[c.color]++;
  let best = "red", bestN = -1;
  for (const c of COLORS) if (counts[c] > bestN) { bestN = counts[c]; best = c; }
  return best;
}

function botPickTarget(g, botId) {
  const opps = g.players.filter((p) => p !== botId);
  opps.sort((a, b) => (g.hands[a] || []).length - (g.hands[b] || []).length);
  return opps[0]; // kazanmaya en yakın (en az kartlı) rakibi hedefle
}

function scheduleBot() {
  if (botTimer) { clearTimeout(botTimer); botTimer = null; }
  if (!isLocal() || !LOCAL || LOCAL.status !== "playing") return;
  const cur = LOCAL.currentTurn;
  if (!isBot(cur)) return;
  botTimer = setTimeout(() => { botTimer = null; runBotMove(cur); }, 2000);
}

async function runBotMove(botId) {
  if (!isLocal() || !LOCAL || LOCAL.status !== "playing" || LOCAL.currentTurn !== botId) return;
  if (isGameDeadlocked(LOCAL)) {
    await endGameStalemate();
    return;
  }
  suppressLocalRender = true;
  playerId = botId;
  try {
    let g = LOCAL;
    let hand = g.hands[botId] || [];
    let playable = unoPlayable(hand, g);
    if (playable.length === 0) {
      await drawCard();
      g = LOCAL; hand = g.hands[botId] || [];
      playable = unoPlayable(hand, g);
    }
    if (playable.length > 0) {
      const card = botPickCard(playable, g, botId);
      const finisher = hand.length === 1;
      const chosenColor = !finisher && isWild(card) ? botPickColor(hand) : null;
      let targetId = null;
      if (!finisher && (card.type === "drawTwo" || card.type === "wildDrawFour" || card.type === "skip")) {
        targetId = botPickTarget(g, botId);
      }
      await playCard(card.id, chosenColor, targetId);
    } else {
      await pass();
    }
  } finally {
    playerId = humanId;
    suppressLocalRender = false;
  }
  maybeEndStalemate();
  if (localCb) localCb(localSnap()); // render + sonraki sıra
}

// ------------------------------------------------------------------
// Görünüm (render)
// ------------------------------------------------------------------
// Köşe rakamı/sembolü (küçük).
function cornerSym(c) {
  switch (c.type) {
    case "number": return String(c.value);
    case "skip": return "Ø";
    case "reverse": return "⇄";
    case "drawTwo": return "+2";
    case "wild": return "";
    case "wildDrawFour": return "+4";
    default: return "";
  }
}

// --- Kart sembolleri (SVG çizimleri) ---
function svgSkip(c) {
  return `<svg viewBox="0 0 100 100" fill="none" stroke="${c}" stroke-width="13">` +
    `<circle cx="50" cy="50" r="33"/><line x1="27" y1="73" x2="73" y2="27"/></svg>`;
}
function svgReverse(c) {
  return `<svg viewBox="0 0 100 100" fill="none" stroke="${c}" stroke-width="10" ` +
    `stroke-linecap="round" stroke-linejoin="round"><g transform="rotate(35 50 50)">` +
    `<path d="M38 26 V72 M38 26 l-10 13 M38 26 l10 13"/>` +
    `<path d="M62 74 V28 M62 74 l-10 -13 M62 74 l10 -13"/></g></svg>`;
}
function svgTwoCards(c) {
  return `<svg viewBox="0 0 100 100"><g stroke="#fff" stroke-width="5" stroke-linejoin="round">` +
    `<rect x="20" y="24" width="40" height="56" rx="7" fill="${c}" transform="rotate(-16 40 52)"/>` +
    `<rect x="40" y="20" width="40" height="56" rx="7" fill="${c}" transform="rotate(-16 60 48)"/></g></svg>`;
}
function svgWild() {
  // Joker: 4 renkli çember (renk seçilse de kartın joker olduğu belli olsun).
  return `<svg viewBox="0 0 100 100" stroke="#fff" stroke-width="2">` +
    `<path d="M50 50 L50 15 A35 35 0 0 1 85 50 Z" fill="#d32f2f"/>` +
    `<path d="M50 50 L85 50 A35 35 0 0 1 50 85 Z" fill="#f9a825"/>` +
    `<path d="M50 50 L50 85 A35 35 0 0 1 15 50 Z" fill="#388e3c"/>` +
    `<path d="M50 50 L15 50 A35 35 0 0 1 50 15 Z" fill="#1976d2"/></svg>`;
}
function svgFourCards() {
  return `<svg viewBox="0 0 100 100"><g stroke="#fff" stroke-width="4" stroke-linejoin="round">` +
    `<rect x="26" y="26" width="30" height="46" rx="5" fill="#1976d2" transform="rotate(-26 50 52)"/>` +
    `<rect x="33" y="24" width="30" height="46" rx="5" fill="#d32f2f" transform="rotate(-9 50 52)"/>` +
    `<rect x="39" y="24" width="30" height="46" rx="5" fill="#388e3c" transform="rotate(9 50 52)"/>` +
    `<rect x="46" y="26" width="30" height="46" rx="5" fill="#f9a825" transform="rotate(26 50 52)"/></g></svg>`;
}

function cardHtml(card, opts = {}) {
  const { faceDown = false, small = false, big = false, playable = false, clickable = false, colorOverride = null } = opts;
  const w = small ? 34 : big ? 84 : 62;
  const sv = `--w:${w}px`;
  const pl = playable ? " playable" : "";

  // Arka yüz (kırmızı UNO logolu).
  if (!card || faceDown) {
    return `<div class="card back" style="${sv}"><span class="oval"></span><span class="back-logo">UNO</span></div>`;
  }

  const click = clickable ? ` data-card="${card.id}"` : "";
  const isWildCard = card.color === "wild";

  // Joker (renk seçilmemiş): ovalde 4 renk.
  if (isWildCard && !colorOverride) {
    if (card.type === "wild") {
      return `<div class="card wild${pl}" style="${sv}"${click}>` +
        `<span class="oval wildoval"></span></div>`;
    }
    // +4: beyaz oval + dört renkli mini kart
    return `<div class="card wild${pl}" style="${sv}"${click}>` +
      `<span class="corner tl">+4</span>` +
      `<span class="oval"></span><span class="pip">${svgFourCards()}</span>` +
      `<span class="corner br">+4</span></div>`;
  }

  // Renkli kart (joker ise seçilen renkle gösterilir).
  const color = isWildCard ? colorOverride : card.color;
  const hex = cssColor(color);
  let center;
  if (card.type === "number") center = `<span class="pip num pip-${color}">${card.value}</span>`;
  else if (card.type === "skip") center = `<span class="pip">${svgSkip(hex)}</span>`;
  else if (card.type === "reverse") center = `<span class="pip">${svgReverse(hex)}</span>`;
  else if (card.type === "drawTwo") center = `<span class="pip">${svgTwoCards(hex)}</span>`;
  else if (card.type === "wildDrawFour") center = `<span class="pip num pip-${color}">+4</span>`; // seçili renkli +4
  else center = `<span class="pip">${svgWild()}</span>`; // seçili renkli joker

  return `<div class="card ${color}${pl}" style="${sv}"${click}>` +
    `<span class="corner tl">${cornerSym(card)}</span>` +
    `<span class="oval"></span>${center}` +
    `<span class="corner br">${cornerSym(card)}</span></div>`;
}

// Oyun bitince kazananın son attığı kart görülsün diye sonuç ekranına
// geçmeden önce 2 saniye tahtayı göstermeye devam ederiz.
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
      if (!resultDelayTimer) {
        resultDelayTimer = setTimeout(() => {
          resultDelayTimer = null;
          showResult = true;
          render();
        }, RESULT_DELAY_MS);
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
        <div class="logo">UNO</div>
        <div class="logo-sub">ONLINE</div>
      </div>
      <input id="name" placeholder="Adınız / Nickname" maxlength="${MAX_NAME_LENGTH}" value="${escapeHtml(playerName)}" />
      <button class="btn-uno" id="vscpu" style="width:100%;animation:none">🤖 Bilgisayara Karşı Oyna</button>
      <div class="divider"></div>
      <button class="btn-primary" id="create" ${FB_READY ? "" : "disabled style='opacity:.5'"}>Yeni Oyun Kur</button>
      <input id="code" placeholder="Oda Kodu (örn. K7P2M)" style="text-transform:uppercase" />
      <button class="btn-outline" id="join" ${FB_READY ? "" : "disabled style='opacity:.5'"}>Oyuna Katıl</button>
      <div class="muted">${FB_READY ? "Online: 2-4 kişi · Bilgisayara karşı: 2-4 kişi" : "Online oyun için Firebase ayarı gerekli (README). Bilgisayara karşı yine oynanır."}</div>
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
    localStorage.setItem("uno_name", playerName);
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

// "Bilgisayara Karşı" — kaç oyuncu (1 insan + botlar) seçim ekranı.
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
  const players = seatOrderLeftToRight(state.players || [], playerId, state?.direction || 1);
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

// Son hamle mesajı yalnızca gerçekten oynanmış bir hamleyle uyumluysa gösterilir.
function shouldShowLastAction() {
  const la = state?.lastAction;
  if (!la) return false;
  if (la.cardType === "stalemate") return state.status === "finished";
  if (state.status !== "playing") return false;

  const pile = state.discardPile || [];
  // Sadece açılış kartı varsa henüz hamle yoktur; önceki oyundan kalan mesajı gizle.
  if (pile.length <= 1) return false;

  if (la.cardType === "pass") return true;

  const top = pile[pile.length - 1];
  if (!top) return false;

  switch (la.cardType) {
    case "number":
      return top.type === "number" && top.color === la.cardColor && top.value === la.cardValue;
    case "skip":
    case "reverse":
    case "drawTwo":
      return top.type === la.cardType && top.color === la.cardColor;
    case "wild":
    case "wildDrawFour":
      return top.type === la.cardType;
    default:
      return false;
  }
}

// Son hamleyi okunur bir cümleye çevirir (kim kimi blokladı / kime kaç kart çektirdi).
function lastActionText() {
  const la = state.lastAction;
  if (!la) return "";
  const who = escapeHtml(state.playerNames[la.player] || "Oyuncu");
  const tgt = la.target ? escapeHtml(state.playerNames[la.target] || "Oyuncu") : "";
  switch (la.cardType) {
    case "skip": return `🚫 ${who} → ${tgt} bloklandı`;
    case "drawTwo": return `➕2 ${who} → ${tgt}'e 2 kart çektirdi`;
    case "wildDrawFour": return `➕4 ${who} → ${tgt}'e 4 kart çektirdi (renk seçti)`;
    case "reverse": return `🔄 ${who} Reverse oynadı (tekrar oynuyor)`;
    case "wild": return `🎨 ${who} Joker oynadı (renk seçti)`;
    case "number": return `${who} ${COLOR_TR[la.cardColor] || ""} ${la.cardValue} oynadı`;
    case "pass": return `⏭️ ${who} pas geçti`;
    case "stalemate": return "🤝 Hamle şansı kalmadı — oyun berabere bitti";
    default: return "";
  }
}

function finishStatusBanner(g) {
  if (g.status !== "finished") return null;
  const w = g.winner;
  if (w == null) {
    return { cls: "theirs", text: "🤝 Hamle şansı kalmadı — berabere bitti" };
  }
  if (w === playerId) {
    return { cls: "mine", text: "🎉 Oyunu bitirdin!" };
  }
  const name = escapeHtml(g.playerNames[w] || "Oyuncu");
  return { cls: "theirs", text: `🏆 ${name} kazandı!` };
}

// Eli renk gruplarına göre dizer (kırmızı, sarı, yeşil, mavi, jokerler en
// sonda); aynı renk içinde önce sayılar (küçükten büyüğe), sonra aksiyon
// kartları. Yalnızca görüntüleme sırasıdır — oyun durumundaki el değişmez,
// böylece açılışta ve sonradan çekilen kartlar hep renk grubunun yanına oturur.
const HAND_COLOR_ORDER = { red: 0, yellow: 1, green: 2, blue: 3, wild: 4 };
const HAND_TYPE_ORDER = { number: 0, skip: 1, reverse: 2, drawTwo: 3, wild: 0, wildDrawFour: 1 };
function sortedHand(hand) {
  return [...hand].sort((a, b) =>
    (HAND_COLOR_ORDER[a.color] - HAND_COLOR_ORDER[b.color]) ||
    (HAND_TYPE_ORDER[a.type] - HAND_TYPE_ORDER[b.type]) ||
    ((a.value ?? 0) - (b.value ?? 0)));
}

function renderBoard() {
  const players = state.players;
  const finished = state.status === "finished";
  const finishBanner = finishStatusBanner(state);
  const isMyTurn = !finished && state.currentTurn === playerId;
  const myHand = state.hands[playerId] || [];
  const top = state.discardPile[state.discardPile.length - 1];
  const dir = state.direction || 1;
  const hasDrawn = !!state.hasDrawn;
  const reverseColor = state.reverseColor || null; // reverse kilidi (varsa)

  // Reverse kilidi varken aynı renk, reverse, +2, Joker ya da +4 oynanabilir.
  const playableNow = (c) => isMyTurn && (
    reverseColor != null
      ? canPlayUnderReverseLock(c, reverseColor)
      : canPlay(c, top, state.currentColor)
  );

  // Diğer oyuncular: sıra yönünde soldan sağa.
  const blockedList = state.blockedPlayers || [];
  const others = opponentsLeftToRight(players, playerId, dir);
  const oppHtml = others.map((p) => {
    const count = (state.hands[p] || []).length;
    const isTurn = finished
      ? (state.winner != null && p === state.winner)
      : state.currentTurn === p;
    const blk = blockedList.filter((x) => x === p).length;
    const unoBit = count === 1 ? `<div class="uno-tag">UNO</div>` : "";
    return `
      <div class="opp ${isTurn ? "opp-turn" : ""}">
        <div class="opp-name">${escapeHtml(state.playerNames[p] || "Oyuncu")}</div>
        <div class="opp-cards">${
          Array.from({ length: Math.min(count, MAX_OPP_CARD_VISUAL) }, () => cardHtml(null, { faceDown: true, small: true })).join("")
        }</div>
        ${blk > 0 ? `<div class="blocked-tag">🚫 bloklu${blk > 1 ? " ×" + blk : ""}</div>` : ""}
        <div class="muted">${count} kart</div>
        ${unoBit}
      </div>`;
  }).join("");
  const iAmBlocked = blockedList.includes(playerId);

  const handHtml = sortedHand(myHand).map((c) =>
    cardHtml(c, { clickable: !finished, playable: playableNow(c) })
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

      ${shouldShowLastAction() ? `<div class="last-action">${lastActionText()}</div>` : ""}
      ${iAmBlocked ? `<div class="last-action" style="color:#ff8a80">🚫 Bloklandın</div>` : ""}

      <div class="turn ${finishBanner ? finishBanner.cls : (isMyTurn ? "mine" : "theirs")}">
        ${finishBanner
          ? finishBanner.text
          : (isMyTurn ? "● Sıra sende" : "○ Sıra: " + escapeHtml(state.playerNames[state.currentTurn] || "Oyuncu"))}
        ${!finished && isMyTurn && reverseColor != null
          ? `<div class="hint">↩️ Reverse! Sadece <b>${COLOR_TR[reverseColor] || reverseColor}</b>, başka bir Reverse, +2, Joker ya da +4 oyna — yoksa çek/pas.</div>`
          : ""}
      </div>

      <div class="actions">
        ${isMyTurn && hasDrawn ? `<button class="btn-pass" id="pass">Pas Geç ▶</button>` : ""}
      </div>

      <div class="hand">${handHtml}</div>
    </div>`;

  document.getElementById("leave").onclick = leaveRoom;

  const deckEl = app.querySelector(".middle .pile .card.back");
  if (deckEl && isMyTurn && !hasDrawn) deckEl.onclick = drawCard;

  const passBtn = document.getElementById("pass");
  if (passBtn) passBtn.onclick = pass;

  app.querySelectorAll(".hand .card[data-card]").forEach((el) => {
    el.onclick = () => tryPlay(el.getAttribute("data-card"));
  });
}

function renderResult() {
  const tie = state.winner == null;
  const iWon = !tie && state.winner === playerId;
  const winnerName = iWon ? "Sen" : (state.playerNames[state.winner] || "Rakip");
  app.innerHTML = `
    <div class="center">
      <div class="emoji">${tie ? "🤝" : (iWon ? "🎉" : "😔")}</div>
      <div style="font-size:28px;font-weight:800">${tie ? "Berabere!" : (iWon ? "Kazandın!" : "Kaybettin")}</div>
      <div class="muted">${tie
        ? "Hamle şansı kalmadığı için oyun berabere sonlandırıldı."
        : (iWon ? "Sen oyunu kazandın." : `${escapeHtml(winnerName)} oyunu kazandı.`)}</div>
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
    ? canPlayUnderReverseLock(card, reverseColor)
    : canPlay(card, top, state.currentColor);
  if (!ok) {
    return toast(reverseColor != null
      ? `Reverse sonrası sadece ${COLOR_TR[reverseColor] || ""}, Reverse, +2, Joker ya da +4 oynayabilirsin.`
      : "Bu kart oynanamaz.");
  }

  // Son kartla bitişte renk/hedef seçimi ve ceza uygulanmaz.
  const finisher = myHand.length === 1;

  // Joker / +4 → renk seç (bitiş kartı değilse).
  let chosenColor = null;
  if (!finisher && (card.type === "wild" || card.type === "wildDrawFour")) {
    chosenColor = await pickColor();
    if (!chosenColor) return;
  }

  // +2 / +4 → kartların ekleneceği oyuncu; Skip → bloklanacak oyuncu.
  let targetId = null;
  if (!finisher) {
    if (card.type === "drawTwo" || card.type === "wildDrawFour") {
      targetId = await pickPlayer("Kime eklensin?");
      if (!targetId) return;
    } else if (card.type === "skip") {
      targetId = await pickPlayer("Kimi blokla?");
      if (!targetId) return;
    }
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
      </div>
      <button class="target-cancel" style="margin-top:16px">↩ Oyuna Geri Dön</button>
    </div>`;
    ov.querySelectorAll(".swatch").forEach((s) => {
      s.onclick = () => { document.body.removeChild(ov); resolve(s.getAttribute("data-c")); };
    });
    // Renk seçmeden vazgeçme (telefonun geri tuşuna gerek kalmadan).
    ov.querySelector(".target-cancel").onclick = () => { document.body.removeChild(ov); resolve(null); };
    document.body.appendChild(ov);
  });
}

// Bir hedef oyuncu seçtiren diyalog (kendisi hariç). +2/+4 için "kime eklensin",
// Skip için "kimi blokla" gibi bir başlıkla kullanılır.
function pickPlayer(title) {
  return new Promise((resolve) => {
    const targets = opponentsLeftToRight(state.players || [], playerId, state.direction || 1);
    if (targets.length === 1) return resolve(targets[0]); // tek rakip → otomatik
    const ov = document.createElement("div");
    ov.className = "overlay";
    ov.innerHTML = `<div class="picker"><div style="font-weight:700">${escapeHtml(title || "Kime?")}</div>
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

// Sessiz hataları görünür kıl (özellikle kurulu uygulamada tanı için yardımcı).
window.addEventListener("unhandledrejection", (e) => {
  if (connecting) {
    connecting = false;
    lastError = _friendlyError(e.reason || new Error("Beklenmeyen hata"));
    render();
  }
  toast("Hata: " + _friendlyError(e.reason || new Error("bilinmiyor")));
});

// ------------------------------------------------------------------
// Telefon "geri" tuşu: oyundan direkt çıkmasın.
// - Açık bir seçim penceresi (renk/hedef) varsa onu kapatır.
// - Oyun içindeysen "çıkmak istediğine emin misin?" diye sorar.
// - Ana ekrandaysan normal geri (uygulamadan çıkış) çalışır.
// ------------------------------------------------------------------
history.pushState({ app: true }, "");
window.addEventListener("popstate", () => {
  const ov = document.querySelector(".overlay");
  if (ov) {
    history.pushState({ app: true }, ""); // uygulamada kal
    const cancel = ov.querySelector(".target-cancel");
    if (cancel) cancel.click(); else ov.remove();
    return;
  }
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
  // Ana ekran: geri tuşu normal çalışsın (uygulamadan çık).
});

// İlk çizim
render();
