import 'package:flutter/foundation.dart';

import '../models/pisti_board_controller.dart';
import '../models/pisti_card.dart';
import '../models/pisti_game_state.dart';
import '../services/pisti_bot_service.dart';
import '../services/pisti_engine.dart';

/// "Bilgisayara Karşı Oyna" modunu yöneten yerel (Firestore'suz) Pişti
/// motoru. Kurallar [PistiEngine] üzerinden online modla birebir aynıdır;
/// tek fark bu motorun durumu cihaz içinde tutması ve rakiplerin bot
/// olmasıdır. İnternet ya da Firebase gerekmez.
class PistiLocalProvider extends ChangeNotifier implements PistiBoardController {
  static const String humanId = 'you';
  static const Duration _collectDelay = Duration(milliseconds: 1200);
  static const Duration _endGameCaptureDelay = Duration(milliseconds: 2000);
  static const Duration _botMoveDelay = Duration(milliseconds: 2000);

  @override
  PistiGameState? state;

  int _session = 0;
  bool _botLoopRunning = false;

  @override
  String get selfId => humanId;

  @override
  bool get isMyTurn => state?.currentTurn == humanId && state?.pendingCapture == null;
  @override
  List<PistiCard> get myHand => state?.hands[humanId] ?? const [];
  @override
  int wonCount(String id) => state?.won[id]?.length ?? 0;
  @override
  int pistiCountFor(String id) => state?.pistiCount[id] ?? 0;

  @override
  List<String> get opponents =>
      state?.players.where((p) => p != humanId).toList() ?? const [];

  @override
  String opponentName(String id) => state?.playerNames[id] ?? id;
  @override
  int opponentCardCount(String id) => state?.hands[id]?.length ?? 0;
  @override
  String? opponentPhoto(String id) {
    final photo = state?.playerPhotos[id];
    return (photo != null && photo.isNotEmpty) ? photo : null;
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

    state = PistiEngine.dealNewGame(
      id: 'local',
      players: players,
      playerNames: names,
      playerPhotos: photos,
    );
    notifyListeners();
    _scheduleBotLoop(session);
  }

  /// Aynı oyuncu sayısıyla yeni bir yerel oyun başlatır.
  void rematch() {
    startGame(
      playerName: _lastPlayerName,
      totalPlayers: _lastTotalPlayers,
      photo: _lastPhoto,
    );
  }

  @override
  Future<void> leaveGame() async {
    _session++;
    state = null;
    notifyListeners();
  }

  @override
  Future<void> playCard(PistiCard card) async {
    final s = state;
    if (s == null) return;
    final result = PistiEngine.playCard(state: s, playerId: humanId, card: card);
    if (result == null) return;
    state = result;
    notifyListeners();
    if (state?.pendingCapture != null) {
      await _resolveCapture(_session);
    }
    _scheduleBotLoop(_session);
  }

  Future<void> _resolveCapture(int session) async {
    final pending = state?.pendingCapture;
    final delay = pending?.endsGame == true ? _endGameCaptureDelay : _collectDelay;
    await Future.delayed(delay);
    if (session != _session) return;
    final s = state;
    if (s == null || s.pendingCapture == null) return;
    final result = PistiEngine.collectPile(state: s);
    if (result == null) return;
    state = result;
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
        if (s.pendingCapture != null) break; // masa toplanana kadar bekle
        if (s.currentTurn == humanId) break;
        await Future.delayed(_botMoveDelay);
        if (session != _session) break;
        final s2 = state;
        if (s2 == null || s2.status != 'playing' || s2.currentTurn == humanId) {
          break;
        }
        final botId = s2.currentTurn;
        final card = PistiBotService.choose(s2, botId);
        final result = PistiEngine.playCard(state: s2, playerId: botId, card: card);
        if (result == null) break;
        state = result;
        notifyListeners();
        if (state?.pendingCapture != null) {
          await _resolveCapture(session);
        }
      }
    } finally {
      _botLoopRunning = false;
    }
  }
}
