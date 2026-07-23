import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/uno_board_controller.dart';
import '../models/uno_card.dart';
import '../services/uno_bot_service.dart';
import '../services/uno_engine.dart';

/// "Bilgisayara Karşı Oyna" modunu yöneten yerel (Firestore'suz) UNO motoru.
/// Kurallar [UnoEngine] üzerinden online modla birebir aynıdır; tek fark bu
/// motorun durumu cihaz içinde tutması ve rakiplerin bot olmasıdır. İnternet
/// ya da Firebase gerekmez.
class LocalUnoProvider extends ChangeNotifier implements UnoBoardController {
  static const String humanId = 'you';
  static const Duration _botMoveDelay = Duration(milliseconds: 2000);

  @override
  GameState? state;

  int _session = 0;
  bool _botLoopRunning = false;

  @override
  String get selfId => humanId;

  @override
  bool get isMyTurn => state?.currentTurn == humanId;
  @override
  bool get hasDrawn => state?.hasDrawn ?? false;
  @override
  CardColor? get reverseColor => state?.reverseColor;
  @override
  List<UnoCard> get myHand => state?.hands[humanId] ?? const [];
  @override
  bool get iWon => state?.winner == humanId;

  /// İnsan oyuncu hariç, sıra yönünde soldan sağa diğer oyuncular (botlar).
  @override
  List<String> get opponents =>
      state?.players.where((p) => p != humanId).toList() ?? const [];

  @override
  String opponentName(String id) => state?.playerNames[id] ?? id;
  @override
  int opponentCardCount(String id) => state?.hands[id]?.length ?? 0;
  @override
  int blockedCount(String id) => state?.blockedPlayers.where((p) => p == id).length ?? 0;
  @override
  String? opponentPhoto(String id) {
    final photo = state?.playerPhotos[id];
    return (photo != null && photo.isNotEmpty) ? photo : null;
  }

  @override
  bool canPlay(UnoCard card) {
    final s = state;
    if (s == null || !isMyTurn) return false;
    return UnoEngine.isPlayable(card, s);
  }

  String _lastPlayerName = '';
  int _lastTotalPlayers = 2;
  String? _lastPhoto;

  void startGame({
    required String playerName,
    required int totalPlayers,
    String? photo,
  }) {
    _lastPlayerName = playerName;
    _lastTotalPlayers = totalPlayers;
    _lastPhoto = photo;
    _session++;
    final session = _session;

    final players = ['you', for (var i = 1; i < totalPlayers; i++) 'bot$i'];
    final names = <String, String>{
      'you': playerName.isEmpty ? 'Sen' : playerName,
      for (var i = 1; i < totalPlayers; i++) 'bot$i': '🤖 Oyuncu $i',
    };
    final photos = <String, String>{
      if (photo != null && photo.isNotEmpty) 'you': photo,
    };

    state = UnoEngine.dealNewGame(
      id: 'local',
      players: players,
      playerNames: names,
      playerPhotos: photos,
    );
    notifyListeners();
    _scheduleBotLoop(session);
  }

  /// Aynı oyuncu sayısıyla yeni bir yerel oyun başlatır (web'deki `rematch()`
  /// fonksiyonunun yerel dal karşılığı).
  void rematch() {
    startGame(
      playerName: _lastPlayerName,
      totalPlayers: _lastTotalPlayers,
      photo: _lastPhoto,
    );
  }

  @override
  Future<void> playCard(UnoCard card, {CardColor? chosenColor, String? targetId}) async {
    final s = state;
    if (s == null) return;
    final result = UnoEngine.playCard(
      state: s,
      playerId: humanId,
      card: card,
      chosenColor: chosenColor,
      targetId: targetId,
    );
    if (result == null) return;
    state = result;
    notifyListeners();
    _scheduleBotLoop(_session);
  }

  @override
  Future<void> drawCard() async {
    final s = state;
    if (s == null) return;
    final result = UnoEngine.drawCard(state: s, playerId: humanId);
    if (result == null) return;
    state = result;
    notifyListeners();
  }

  @override
  Future<void> pass() async {
    final s = state;
    if (s == null) return;
    final result = UnoEngine.pass(state: s, playerId: humanId);
    if (result == null) return;
    state = result;
    notifyListeners();
    _scheduleBotLoop(_session);
  }

  /// Oyundan çıkıp giriş ekranına döner; bekleyen bot hamlelerini iptal eder.
  @override
  Future<void> leaveGame() async {
    _session++;
    state = null;
    notifyListeners();
  }

  /// Sıradaki oyuncu(lar) bot olduğu sürece kısa gecikmelerle hamlelerini
  /// oynatır; insanın sırası gelince ya da oyun bitince durur.
  Future<void> _scheduleBotLoop(int session) async {
    if (_botLoopRunning) return;
    _botLoopRunning = true;
    try {
      while (true) {
        final s = state;
        if (s == null || s.status != 'playing' || session != _session) break;
        if (s.currentTurn == humanId) break;
        await Future.delayed(_botMoveDelay);
        if (session != _session) break;
        final s2 = state;
        if (s2 == null || s2.status != 'playing' || s2.currentTurn == humanId) {
          break;
        }
        _runBotMove(s2.currentTurn);
      }
    } finally {
      _botLoopRunning = false;
    }
  }

  void _runBotMove(String botId) {
    final s = state!;
    final hand = s.hands[botId] ?? const [];
    var playableCards = UnoBotService.playable(hand, s);

    if (playableCards.isEmpty) {
      final afterDraw = UnoEngine.drawCard(state: s, playerId: botId);
      if (afterDraw == null) return;
      state = afterDraw;
      notifyListeners();
      final drawnHand = afterDraw.hands[botId] ?? const [];
      playableCards = UnoBotService.playable(drawnHand, afterDraw);
      if (playableCards.isEmpty) {
        final passed = UnoEngine.pass(state: afterDraw, playerId: botId);
        if (passed != null) {
          state = passed;
          notifyListeners();
        }
        return;
      }
    }

    final current = state!;
    final card = UnoBotService.pickCard(playableCards, current, botId);
    final remaining = (current.hands[botId] ?? const []).where((c) => c.id != card.id).toList();
    final finisher = (current.hands[botId] ?? const []).length == 1;
    final chosenColor = !finisher && card.isWild ? UnoBotService.pickColor(remaining) : null;
    String? targetId;
    if (!finisher &&
        (card.type == CardType.skip ||
            card.type == CardType.drawTwo ||
            card.type == CardType.wildDrawFour)) {
      targetId = UnoBotService.pickTarget(current, botId);
    }
    final result = UnoEngine.playCard(
      state: current,
      playerId: botId,
      card: card,
      chosenColor: chosenColor,
      targetId: targetId,
    );
    if (result != null) {
      state = result;
      notifyListeners();
    }
  }
}
