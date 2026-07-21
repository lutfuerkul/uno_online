import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/okey_board_controller.dart';
import '../models/okey_game_state.dart';
import '../models/okey_tile.dart';
import '../theme/okey_theme.dart';
import 'okey_rack_painter.dart';
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
                          width: 26,
                          isOkey: state.isOkey(discard),
                        )
                      : SizedBox(
                          width: 26,
                          height: 26 * 1.5,
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
    final deckCount = state.drawPile.length;
    final leftDiscard = c.takeableDiscard;

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
                _indicatorCard(state),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pileColumn(
                      label: 'Deste ($deckCount)',
                      child: deckCount > 0
                          ? const OkeyTileWidget(faceDown: true, width: 58)
                          : _emptySlot(58),
                      hint: canDraw && deckCount > 0 ? 'çekmek için dokun' : null,
                      onTap: canDraw && deckCount > 0
                          ? () => c.drawFromStack()
                          : null,
                    ),
                    const SizedBox(width: 28),
                    _pileColumn(
                      label: 'Yerde (sol)',
                      child: leftDiscard != null
                          ? OkeyTileWidget(
                              tile: leftDiscard,
                              width: 58,
                              isOkey: state.isOkey(leftDiscard),
                            )
                          : _emptySlot(58),
                      hint: canDraw && leftDiscard != null
                          ? 'almak için dokun'
                          : null,
                      onTap: canDraw && leftDiscard != null
                          ? () => c.drawFromDiscard()
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _indicatorCard(OkeyGameState state) {
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
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            children: [
              const Text('Gösterge',
                  style: TextStyle(color: OkeyColors.label, fontSize: 11)),
              const SizedBox(height: 4),
              OkeyTileWidget(tile: ind, width: 40),
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
              const Text('ve iki sahte okey joker',
                  style: TextStyle(color: OkeyColors.muted, fontSize: 11)),
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
                color: onTap != null
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

  Widget _emptySlot(double width) {
    return Container(
      width: width,
      height: width * 1.5,
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
    final selected = _selectedTile(myHand);

    return Container(
      color: OkeyColors.topbar,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _smallButton('↔ Renk sırala',
                  () => c.arrangeHand(byGroups: false)),
              const SizedBox(width: 6),
              _smallButton('# Grupla', () => c.arrangeHand(byGroups: true)),
              const Spacer(),
              if (canDiscard && selected != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.canFinish
                        ? OkeyColors.accent
                        : OkeyColors.primary,
                    foregroundColor:
                        c.canFinish ? Colors.black : Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () => _discardSelected(context, selected),
                  child: Text(c.canFinish ? '🎉 Seçili taşı at' : 'Seçili taşı at',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _rackWithTiles(context, state, myHand, canDiscard),
        ],
      ),
    );
  }

  Widget _rackWithTiles(BuildContext context, OkeyGameState state,
      List<OkeyTile> myHand, bool canDiscard) {
    const tileW = 40.0;
    const gap = 3.0;
    final tileH = tileW * 1.5;
    final rackH = tileH + 30;
    final contentW = myHand.length * (tileW + gap) + 24;

    return SizedBox(
      height: rackH,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(contentW, MediaQuery.of(context).size.width - 16),
          height: rackH,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: const OkeyRackPainter()),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 10, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final tile in myHand) ...[
                      OkeyTileWidget(
                        tile: tile,
                        width: tileW,
                        isOkey: state.isOkey(tile),
                        selected: tile.id == _selectedId,
                        onTap: () => _onTileTap(tile, canDiscard),
                      ),
                      const SizedBox(width: gap),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  OkeyTile? _selectedTile(List<OkeyTile> hand) {
    if (_selectedId == null) return null;
    for (final t in hand) {
      if (t.id == _selectedId) return t;
    }
    return null;
  }

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

  Future<void> _discardSelected(BuildContext context, OkeyTile tile) async {
    setState(() => _selectedId = null);
    await widget.controller.discard(tile);
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
