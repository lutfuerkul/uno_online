import '../models/okey_game_state.dart';
import '../models/okey_tile.dart';
import 'okey_meld_solver.dart';

/// Bot kararları: soldaki ıskarta eli iyileştiriyorsa onu alır, aksi halde
/// desteden çeker; çektikten sonra el açabiliyorsa açar, açamıyorsa boşta
/// kalan (perlere en az katkı yapan) taşı atar. Okey (joker) asla atılmaz
/// (bitişi sağlamıyorsa).
class OkeyBotService {
  /// Botun bu turdaki tam kararı.
  static OkeyBotDecision decide(OkeyGameState state, String botId) {
    final hand = state.hands[botId] ?? const <OkeyTile>[];

    if (!state.hasDrawn) {
      return OkeyBotDecision.draw(_shouldTakeDiscard(state, botId));
    }

    // 15 taş: önce el açmayı dene (çifte için okey atmayı tercih et).
    final winTile = OkeyMeldSolver.winningDiscard(
      hand,
      state.okeyColor,
      state.okeyNumber,
      preferOkey: true,
    );
    if (winTile != null) {
      return OkeyBotDecision.discard(winTile);
    }

    return OkeyBotDecision.discard(_chooseDiscard(state, botId));
  }

  /// Soldaki ıskartadan almak, desteden çekmeye kıyasla eli iyileştiriyorsa
  /// (ya da taş okeyse) true.
  static bool _shouldTakeDiscard(OkeyGameState state, String botId) {
    final n = state.players.length;
    final i = state.players.indexOf(botId);
    final prev = state.players[(i - 1 + n) % n];
    final prevDiscards = state.discards[prev] ?? const [];
    if (prevDiscards.isEmpty) return false;
    final tile = prevDiscards.last;
    if (state.isOkey(tile)) return true;

    final hand = state.hands[botId] ?? const <OkeyTile>[];
    final baseCover =
        OkeyMeldSolver.maxCovered(hand, state.okeyColor, state.okeyNumber);
    final withTile = [...hand, tile];
    final coverWith = OkeyMeldSolver.maxCovered(
        withTile, state.okeyColor, state.okeyNumber);
    // Alınan taş doğrudan bir pere katkı yapıyorsa değerlidir.
    return coverWith > baseCover + 1;
  }

  static OkeyTile _chooseDiscard(OkeyGameState state, String botId) {
    final hand = state.hands[botId] ?? const <OkeyTile>[];
    final justTaken = state.drawnFromDiscardId;

    OkeyTile? best;
    var bestCover = -1;
    for (final tile in hand) {
      if (state.isOkey(tile)) continue; // okey saklanır
      if (justTaken != null && tile.id == justTaken) continue; // geri atılamaz
      final rest = [
        for (final t in hand)
          if (t.id != tile.id) t,
      ];
      final cover =
          OkeyMeldSolver.maxCovered(rest, state.okeyColor, state.okeyNumber);
      if (cover > bestCover) {
        bestCover = cover;
        best = tile;
      }
    }

    // Tüm taşlar okeyse (neredeyse imkânsız) ya da hepsi elenmişse ilk atılabilir
    // taşa düş.
    return best ??
        hand.firstWhere(
          (t) => justTaken == null || t.id != justTaken,
          orElse: () => hand.first,
        );
  }
}

class OkeyBotDecision {
  /// 'draw' | 'discard'
  final String type;

  /// type == 'draw' için: soldaki ıskartadan mı alınacak?
  final bool fromDiscard;

  /// type == 'discard' için: atılacak taş.
  final OkeyTile? tile;

  const OkeyBotDecision._(this.type, this.fromDiscard, this.tile);

  factory OkeyBotDecision.draw(bool fromDiscard) =>
      OkeyBotDecision._('draw', fromDiscard, null);
  factory OkeyBotDecision.discard(OkeyTile tile) =>
      OkeyBotDecision._('discard', false, tile);
}
