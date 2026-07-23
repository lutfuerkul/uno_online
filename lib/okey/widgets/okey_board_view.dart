import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/okey_board_controller.dart';
import '../models/okey_game_state.dart';
import '../models/okey_tile.dart';
import '../services/okey_meld_solver.dart';
import '../theme/okey_theme.dart';
import 'okey_tile_widget.dart';

/// Okey tahtası. Hem online (Firestore) hem de bilgisayara karşı (yerel) mod
/// bu widget'ı [OkeyBoardController] üzerinden paylaşır.
class OkeyBoardView extends StatefulWidget {
  final OkeyBoardController controller;
  final String roomLabel;
  final VoidCallback onLeave;

  const OkeyBoardView({
    super.key,
    required this.controller,
    required this.roomLabel,
    required this.onLeave,
  });

  @override
  State<OkeyBoardView> createState() => _OkeyBoardViewState();
}

class _OkeyBoardViewState extends State<OkeyBoardView> {
  String? _selectedId;

  /// Tüm taşların ortak ebadı — "oyuncuların yere attığı taş" boyutu. Masa
  /// ortasındaki taşlar (gösterge, deste, yerdeki, attığım) ve ıstakadaki
  /// taşlar bu boyutta çizilir; ıstakada ekrana sığmazsa otomatik küçülür.
  static const double _tileSize = 33;

  /// Renk sırala/Grupla düğmeleri serbest yerleşimle gereksiz kaldı;
  /// gerekirse tekrar açmak için burayı true yap.
  static const bool _showArrangeButtons = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        if (state == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildBoard(context, state);
      },
    );
  }

  Widget _buildBoard(BuildContext context, OkeyGameState state) {
    final c = widget.controller;
    final myHand = c.myHand;

    // Seçili taş elde yoksa seçimi temizle.
    if (_selectedId != null && !myHand.any((t) => t.id == _selectedId)) {
      _selectedId = null;
    }

    return Column(
      children: [
        _topBar(),
        _opponentsRow(state),
        Expanded(child: _middle(context, state)),
        _turnBanner(state),
        _handArea(context, state),
      ],
    );
  }

  Widget _topBar() {
    return Container(
      color: OkeyColors.topbar,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.roomLabel,
              style: const TextStyle(color: OkeyColors.muted, fontSize: 14)),
          TextButton(
            onPressed: widget.onLeave,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0x1AFFFFFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Çık', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _opponentsRow(OkeyGameState state) {
    final c = widget.controller;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < c.opponents.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _opponentTile(state, c.opponents[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _opponentTile(OkeyGameState state, String id) {
    final c = widget.controller;
    final isTurn = state.currentTurn == id && state.status == 'playing';
    final count = c.opponentTileCount(id);
    final discard = c.topDiscardOf(id);

    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isTurn ? OkeyColors.oppTurnBorder : Colors.transparent,
            width: 2),
        color: isTurn ? OkeyColors.oppTurnBg : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.opponentName(id),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _miniStack(count),
              const SizedBox(width: 8),
              Column(
                children: [
                  const Text('attı',
                      style: TextStyle(color: OkeyColors.muted, fontSize: 10)),
                  const SizedBox(height: 2),
                  discard != null
                      ? OkeyTileWidget(
                          tile: discard,
                          width: _tileSize,
                          isOkey: state.isOkey(discard),
                        )
                      : SizedBox(
                          width: _tileSize,
                          height: _tileSize * OkeyTileWidget.aspect,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0x33FFFFFF)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('$count taş',
              style: const TextStyle(color: OkeyColors.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _miniStack(int count) {
    final n = math.min(count, 5);
    const w = 14.0;
    const overlap = 9.0;
    final step = w - overlap;
    return SizedBox(
      width: w + (n - 1) * step,
      height: w * 1.5,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < n; i++)
            Positioned(
              left: i * step,
              child: const OkeyTileWidget(faceDown: true, width: w),
            ),
        ],
      ),
    );
  }

  Widget _middle(BuildContext context, OkeyGameState state) {
    final c = widget.controller;
    final isMyTurn = c.isMyTurn;
    final canDraw = isMyTurn && !c.hasDrawn && state.status == 'playing';
    final canDiscard = isMyTurn && c.hasDrawn && state.status == 'playing';
    final deckCount = state.drawPile.length;
    final leftDiscard = c.takeableDiscard;
    final myDiscard = c.myLastDiscard;

    return Container(
      color: OkeyColors.middle,
      width: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _indicatorCard(context, state, canDiscard),
                const SizedBox(height: 16),
                // FittedBox: dar telefonlarda orta satır taşmasın diye orantılı
                // küçülür.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kendi en son attığım taş — atılacak taş buraya
                      // sürüklenip bırakılır (normal atış, sıra geçer).
                      _pileColumn(
                        label: 'Attığım',
                        highlight: canDiscard,
                        hint: canDiscard ? 'atmak için sürükle' : null,
                        child: DragTarget<String>(
                          onWillAcceptWithDetails: (d) => canDiscard,
                          onAcceptWithDetails: (d) =>
                              _handleDiscardDrop(context, d.data),
                          builder: (ctx, cand, rej) {
                            final tile = myDiscard != null
                                ? OkeyTileWidget(
                                    tile: myDiscard,
                                    width: _tileSize,
                                    isOkey: state.isOkey(myDiscard),
                                  )
                                : _emptySlot(_tileSize);
                            return cand.isNotEmpty
                                ? _dropHighlight(tile, _tileSize)
                                : tile;
                          },
                        ),
                      ),
                      const SizedBox(width: 20),
                      _pileColumn(
                        label: 'Deste ($deckCount)',
                        child: deckCount > 0
                            ? const OkeyTileWidget(faceDown: true, width: _tileSize)
                            : _emptySlot(_tileSize),
                        hint:
                            canDraw && deckCount > 0 ? 'çekmek için dokun' : null,
                        onTap: canDraw && deckCount > 0
                            ? () => c.drawFromStack()
                            : null,
                      ),
                      const SizedBox(width: 20),
                      _pileColumn(
                        label: 'Yerde',
                        child: leftDiscard != null
                            ? OkeyTileWidget(
                                tile: leftDiscard,
                                width: _tileSize,
                                isOkey: state.isOkey(leftDiscard),
                              )
                            : _emptySlot(_tileSize),
                        hint: canDraw && leftDiscard != null
                            ? 'almak için dokun'
                            : null,
                        onTap: canDraw && leftDiscard != null
                            ? () => c.drawFromDiscard()
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _indicatorCard(
      BuildContext context, OkeyGameState state, bool canDiscard) {
    final ind = state.indicator;
    final okeyColorName = OkeyTile(
      color: state.okeyColor,
      number: state.okeyNumber,
      isFakeJoker: false,
      id: '_',
    ).colorNameTr;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canDiscard ? OkeyColors.okeyGlow : const Color(0x33FFFFFF),
          width: canDiscard ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            children: [
              const Text('Gösterge',
                  style: TextStyle(color: OkeyColors.label, fontSize: 11)),
              const SizedBox(height: 4),
              // Eli bitirmek için: göndereceğin taşı bu gösterge taşının
              // üzerine sürükleyip bırak. Geçerli bitişse el açılır; değilse
              // hiçbir şey olmaz (taş elde kalır).
              DragTarget<String>(
                onWillAcceptWithDetails: (d) => canDiscard,
                onAcceptWithDetails: (d) =>
                    _handleFinishDrop(context, state, d.data),
                builder: (ctx, cand, rej) {
                  final tile = OkeyTileWidget(tile: ind, width: _tileSize);
                  return cand.isNotEmpty
                      ? _dropHighlight(tile, _tileSize)
                      : tile;
                },
              ),
              if (canDiscard)
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text('bitirmek için sürükle',
                      style: TextStyle(color: OkeyColors.okeyGlow, fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('OKEY',
                  style: TextStyle(
                      color: OkeyColors.okeyGlow,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 2)),
              const SizedBox(height: 2),
              Text('$okeyColorName ${state.okeyNumber}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pileColumn({
    required String label,
    required Widget child,
    String? hint,
    VoidCallback? onTap,
    bool highlight = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(color: OkeyColors.label, fontSize: 12)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (onTap != null || highlight)
                    ? OkeyColors.okeyGlow
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: child,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 14,
          child: hint != null
              ? Text(hint,
                  style: const TextStyle(
                      color: OkeyColors.okeyGlow, fontSize: 11))
              : null,
        ),
      ],
    );
  }

  /// Sürüklenen bir taş bu bırakma hedefinin üzerindeyken [child]'ı sarıp
  /// vurgular (parlak kenarlık).
  Widget _dropHighlight(Widget child, double width) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.2),
        border: Border.all(color: OkeyColors.okeyGlow, width: 3),
      ),
      child: child,
    );
  }

  Widget _emptySlot(double width) {
    return Container(
      width: width,
      height: width * OkeyTileWidget.aspect,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.16),
        border: Border.all(color: const Color(0x33FFFFFF), width: 2),
      ),
      child: const Text('boş',
          style: TextStyle(color: Color(0x66FFFFFF), fontSize: 11)),
    );
  }

  Widget _turnBanner(OkeyGameState state) {
    final c = widget.controller;
    final isMyTurn = c.isMyTurn;
    final action = state.lastAction;

    String text;
    if (state.status != 'playing') {
      text = 'El bitti';
    } else if (isMyTurn) {
      if (c.canFinish) {
        text = '🎉 Elini bitirebilirsin — kazandıran taşı at!';
      } else if (!c.hasDrawn) {
        text = '● Sıra sende — desteden çek ya da yerden al';
      } else {
        text = '● Bir taş at';
      }
    } else {
      text = '○ Sıra: ${c.opponentName(state.currentTurn)}';
    }

    return Column(
      children: [
        if (action != null && action.type == 'discard' && state.status == 'playing')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            child: Text(
              '${c.opponentName(action.player)}, ${action.tile?.nameTr ?? ''} attı',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: OkeyColors.lastAction, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          color: isMyTurn ? OkeyColors.turnMine : OkeyColors.turnTheirs,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isMyTurn ? Colors.white : OkeyColors.turnTheirsText,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _handArea(BuildContext context, OkeyGameState state) {
    final c = widget.controller;
    final isMyTurn = c.isMyTurn;
    final canDiscard = isMyTurn && c.hasDrawn && state.status == 'playing';
    final myHand = c.myHand;

    return Container(
      color: OkeyColors.topbar,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Renk sırala" / "Grupla" düğmeleri gizlendi (serbest yerleşim
          // geldiğinden gereksiz kaldılar); "Seçili taşı at" düğmesi de
          // kaldırıldı — atış artık taşı "Attığım" ya da göstergeye
          // sürükleyip bırakarak yapılıyor. Kod korunuyor, gerekirse
          // _showArrangeButtons true yapılıp geri açılabilir.
          if (_showArrangeButtons) ...[
            Row(
              children: [
                _smallButton('↔ Renk sırala',
                    () => c.arrangeHand(byGroups: false)),
                const SizedBox(width: 6),
                _smallButton('# Grupla', () => c.arrangeHand(byGroups: true)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          _rackWithTiles(context, state, myHand, canDiscard),
        ],
      ),
    );
  }

  /// Elimi ıstakaya yuva-ızgarası olarak dizer. Her hücre bir bırakma
  /// hedefidir; taşı boş yuvaya bırakırsan oraya gider, eski yeri boş kalır
  /// (serbest yerleşim + boşluk bırakma). Boş yuvalar soluk gösterilir.
  Widget _rackWithTiles(BuildContext context, OkeyGameState state,
      List<OkeyTile> myHand, bool canDiscard) {
    final byId = {for (final t in myHand) t.id: t};
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const gap = 3.0;
        const hPad = 8.0;
        const borderW = 2.0; // rafın kenarlığı (taşmayı önlemek için düşülür)
        // Taşlar "yere atılan taş" ebatında (_tileSize); ekrana sığmazsa
        // otomatik küçülür (Honor vb. dar telefonlarda taşma olmaz).
        final inner = width - hPad * 2 - borderW * 2;
        var perRow = ((inner + gap) / (_tileSize + gap)).floor();
        perRow = perRow.clamp(1, 30);
        var tileW = (inner - (perRow - 1) * gap) / perRow;
        tileW = tileW.clamp(18.0, _tileSize);
        final tileH = tileW * OkeyTileWidget.aspect;

        final slots = widget.controller.handSlots;
        // En az 2 satır; taşlar sığmıyorsa daha fazla. Kalan hücreler boş yuva.
        final rowsNeeded = (slots.length + perRow - 1) ~/ perRow;
        final rows = math.max(2, rowsNeeded);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: OkeyColors.rackDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x55000000), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rows; r++) ...[
                if (r > 0) const SizedBox(height: gap + 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var col = 0; col < perRow; col++) ...[
                      if (col > 0) const SizedBox(width: gap),
                      Builder(builder: (_) {
                        final i = r * perRow + col;
                        final id = i < slots.length ? slots[i] : null;
                        return _slotCell(
                            i, id, byId[id], tileW, tileH, canDiscard, state);
                      }),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Bir ıstaka hücresi: taş varsa sürüklenebilir taşı, yoksa soluk boş yuvayı
  /// gösterir. Her hücre bir DragTarget'tır; taş bırakılınca o yuvaya konur.
  Widget _slotCell(int index, String? tileId, OkeyTile? tile, double w,
      double h, bool canDiscard, OkeyGameState state) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != tileId,
      onAcceptWithDetails: (d) => widget.controller.placeTile(d.data, index),
      builder: (ctx, cand, rej) {
        final hl = cand.isNotEmpty;
        if (tile == null) {
          return _emptyRackSlot(w, h, hl);
        }
        final tileWidget = OkeyTileWidget(
          tile: tile,
          width: w,
          isOkey: state.isOkey(tile),
          selected: tile.id == _selectedId,
          onTap: () => _onTileTap(tile, canDiscard),
        );
        return Draggable<String>(
          data: tile.id,
          feedback: Material(
            color: Colors.transparent,
            child: OkeyTileWidget(
                tile: tile, width: w * 1.12, isOkey: state.isOkey(tile)),
          ),
          childWhenDragging: _emptyRackSlot(w, h, false),
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                Positioned.fill(child: tileWidget),
                if (hl)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(w * 0.14),
                          border: Border.all(
                              color: OkeyColors.okeyGlow, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Boş yuva (soluk çerçeve). Üzerine taş sürüklenince vurgulanır.
  Widget _emptyRackSlot(double w, double h, bool highlight) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.14),
        color: const Color(0x14000000),
        border: Border.all(
          color: highlight ? OkeyColors.okeyGlow : const Color(0x2E000000),
          width: highlight ? 2 : 1,
        ),
      ),
    );
  }

  /// Taşa dokununca hafifçe kaldırıp seçili gösterir (yalnızca görsel);
  /// atış artık taşı "Attığım" ya da göstergeye sürükleyerek yapılıyor.
  void _onTileTap(OkeyTile tile, bool canDiscard) {
    if (!canDiscard) {
      // Çekme fazında taşı seçmek yerine bilgi ver.
      if (widget.controller.isMyTurn && !widget.controller.hasDrawn) {
        _toast('Önce desteden çek ya da yerden al.');
      }
      return;
    }
    setState(() {
      _selectedId = _selectedId == tile.id ? null : tile.id;
    });
  }

  /// "Attığım" alanına bırakılan taşı normal atış olarak oynar.
  Future<void> _handleDiscardDrop(BuildContext context, String tileId) async {
    final tile = _tileInHand(tileId);
    if (tile == null) return;
    final s = widget.controller.state;
    if (s != null && s.drawnFromDiscardId == tile.id) {
      _toast('Bu taşı hemen geri atamazsın.');
      return;
    }
    setState(() => _selectedId = null);
    await widget.controller.discard(tile);
  }

  /// Göstergeye bırakılan taşla eli bitirmeyi dener. Kalan taşların geçerli
  /// gruplara bölünüp bölünmediği burada (istemci tarafında, motorla aynı
  /// çözücüyle) önceden kontrol edilir; bölünmüyorsa hiçbir şey gönderilmez
  /// ve kullanıcıya bilgi verilir — taş elde kalır.
  Future<void> _handleFinishDrop(
      BuildContext context, OkeyGameState state, String tileId) async {
    final tile = _tileInHand(tileId);
    if (tile == null) return;
    if (state.drawnFromDiscardId == tile.id) {
      _toast('Bu taşı hemen geri atamazsın.');
      return;
    }
    final hand = widget.controller.myHand;
    final rest = [for (final t in hand) if (t.id != tileId) t];
    if (rest.length != 14 ||
        !OkeyMeldSolver.isWinningHand(rest, state.okeyColor, state.okeyNumber)) {
      _toast('Bu taşla eli bitiremezsin.');
      return;
    }
    setState(() => _selectedId = null);
    await widget.controller.finishDiscard(tile);
  }

  OkeyTile? _tileInHand(String tileId) {
    for (final t in widget.controller.myHand) {
      if (t.id == tileId) return t;
    }
    return null;
  }

  Widget _smallButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0x44FFFFFF)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }
}
