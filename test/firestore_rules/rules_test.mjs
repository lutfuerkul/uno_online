import fs from 'fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc } from 'firebase/firestore';

const ALICE = 'alice-uid';
const BOB = 'bob-uid';
const MALLORY = 'mallory-uid';

// isValidUnoGame'in tip kontrollerini karşılayan geçerli bir oda belgesi.
const game = (players, status = 'waiting') => ({
  status,
  players,
  playerNames: Object.fromEntries(players.map((p) => [p, 'Oyuncu'])),
  playerPhotos: {},
  hands: Object.fromEntries(players.map((p) => [p, []])),
  drawPile: [],
  discardPile: [],
  currentColor: 'red',
  currentTurn: players[0] ?? '',
  direction: 1,
  hasDrawn: false,
  unoSafe: [],
  blockedPlayers: [],
  createdAt: 1700000000000,
});

// Kurallar depo kökünden okunur; testin hangi dizinden çalıştırıldığı
// önemli olmasın diye yol bu dosyaya göre çözülüyor.
const rulesPath = new URL('../../firestore.rules', import.meta.url);

const env = await initializeTestEnvironment({
  projectId: 'demo-test',
  firestore: {
    host: '127.0.0.1',
    port: 8080,
    rules: fs.readFileSync(rulesPath, 'utf8'),
  },
});

const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const seed = (id, data) =>
  env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'games', id), data));

let pass = 0, fail = 0;
async function check(name, fn) {
  try { await fn(); console.log('  ✓', name); pass++; }
  catch (e) { console.log('  ✗', name, '\n     ', String(e).split('\n')[0]); fail++; }
}

console.log('\nOKUMA');
await seed('AAAAA', game([ALICE]));
await check('kimlik doğrulaması olmayan okuyamaz',
  () => assertFails(getDoc(doc(db(null), 'games/AAAAA'))));
await check('oturum açmış okuyabilir',
  () => assertSucceeds(getDoc(doc(db(BOB), 'games/AAAAA'))));

console.log('\nODA KURMA');
await check('kendi uid ile oda kurabilir',
  () => assertSucceeds(setDoc(doc(db(ALICE), 'games/BBBBB'), game([ALICE]))));
await check('başkasının uid siyle oda kuramaz',
  () => assertFails(setDoc(doc(db(MALLORY), 'games/CCCCC'), game([ALICE]))));
await check('geçersiz oda kodu reddedilir',
  () => assertFails(setDoc(doc(db(ALICE), 'games/bad-id'), game([ALICE]))));

console.log('\nYAZMA (asıl düzeltme)');
await seed('DDDDD', game([ALICE, BOB], 'playing'));
await check('odadaki oyuncu yazabilir',
  () => assertSucceeds(setDoc(doc(db(ALICE), 'games/DDDDD'), game([ALICE, BOB], 'playing'))));
await check('odada olmayan yabancı YAZAMAZ',
  () => assertFails(setDoc(doc(db(MALLORY), 'games/DDDDD'), game([ALICE, BOB], 'playing'))));
await check('yabancı kendini oyuna sokamaz (playing)',
  () => assertFails(setDoc(doc(db(MALLORY), 'games/DDDDD'), game([ALICE, BOB, MALLORY], 'playing'))));

console.log('\nBEKLEME ODASINA KATILMA');
await seed('EEEEE', game([ALICE]));
await check('bekleme odasına kendini ekleyebilir',
  () => assertSucceeds(setDoc(doc(db(BOB), 'games/EEEEE'), game([ALICE, BOB]))));
await seed('FFFFF', game([ALICE, BOB]));
await check('katılırken mevcut oyuncuyu ATAMAZ',
  () => assertFails(setDoc(doc(db(MALLORY), 'games/FFFFF'), game([ALICE, MALLORY]))));
await check('kendini eklemeden başkasını ekleyemez',
  () => assertFails(setDoc(doc(db(MALLORY), 'games/FFFFF'), game([ALICE, BOB, 'birisi']))));

console.log('\nÇIKMA VE SİLME');
await seed('GGGGG', game([ALICE, BOB], 'playing'));
await check('oyuncu kendini çıkarabilir',
  () => assertSucceeds(setDoc(doc(db(BOB), 'games/GGGGG'), game([ALICE], 'playing'))));
await check('oda silinemez',
  () => assertFails(deleteDoc(doc(db(ALICE), 'games/GGGGG'))));

console.log('\nŞEMA DOĞRULAMA');
await seed('HHHHH', game([ALICE]));
await check('bilinmeyen alan reddedilir',
  () => assertFails(setDoc(doc(db(ALICE), 'games/HHHHH'), { ...game([ALICE]), kotu: 1 })));

await env.cleanup();
console.log(`\n${pass} geçti, ${fail} başarısız`);
process.exit(fail ? 1 : 0);
