import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/okey_board_controller.dart';
import '../models/okey_game_state.dart';
import '../models/okey_tile.dart';
import '../services/okey_meld_solver.dart';
import '../theme/okey_theme.dart';
import 'okey_photo_frame.dart';
import 'okey_tile_widget.dart';

/// Solumdaki oyuncunun (leftPlayerId) attığı taşı "yerden almak" için
/// sürüklenen sinyal — ıstakadaki taşları yeniden dizmek için kullanılan
/// `Draggable<String>` ile karışmasın diye ayrı bir tür.
class _DrawFromDiscardSignal {
  const _DrawFromDiscardSignal();
}

/// Desteden taş çekmek için sürüklenen sinyal — [_DrawFromDiscardSignal]
/// gibi, yalnızca ıstaka hücrelerinin kabul ettiği ayrı bir tür.
class _DrawFromStackSignal {
  const _DrawFromStackSignal();
}

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

  /// Istakada sıra başına her zaman bu kadar taş gösterilir; taş piksel
  /// boyutu ekran genişliğine göre otomatik hesaplanır (bkz. [_rackWithTiles]).
  static const int _rackTilesPerRow = 10;

  /// Renk sırala/Grupla düğmeleri serbest yerleşimle gereksiz kaldı;
  /// gerekirse tekrar açmak için burayı true yap.
  static const bool _showArrangeButtons = false;

  /// Yatay moddaki ıstaka: sıra başına taş sayısı (2 sıra x 14 = 28 göz).
  /// Dikeyin aksine taş boyutu burada sabit kalır, sıkıştırma yapılmaz.
  static const int _landscapeTilesPerRow = 14;

  /// Yatay/dikey modu — yalnızca bu düğmeyle değişir, cihazın fiziksel
  /// döndürmesi hiçbir şeyi etkilemez (SystemChrome her iki modda da tek
  /// bir yöne kilitli tutuyor).
  bool _landscape = false;

  @override
  void dispose() {
    // Ekrandan çıkarken uygulamanın geri kalanını dikeye kilitli bırak.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _toggleOrientation() {
    final next = !_landscape;
    // Istaka yuvaları (slots) tek bir ortak dizi; dikey (10 sütun) ve yatay
    // (14 sütun) farklı sütun sayısı kullandığı için, bir taş diğer moddaki
    // sütun sayısını aşan bir yuvaya (ör. yatayda 2. sıranın sonlarına)
    // bırakılmışsa, öbür moda geçince o yuva 3. sıraya düşüyordu. Geçiş
    // öncesi, hedef moda 2 sırada sığmıyorsa taşları baştan sıkıştırıyoruz.
    _compactSlotsIfOverflowing(next ? _landscapeTilesPerRow : _rackTilesPerRow);
    setState(() => _landscape = next);
    SystemChrome.setPreferredOrientations(_landscape
        ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : const [DeviceOrientation.portraitUp]);
  }

  /// [slots] içindeki dolu son yuvaya göre kaç sıra gerektiğini hesaplar
  /// (ham liste uzunluğu değil — liste geçmişte açılan yuvalardan dolayı
  /// gereğinden uzun kalabiliyor, o zaman da hep 3 sıra gösterirdi).
  int _rowsNeeded(List<String?> slots, int perRow) {
    final lastOccupied = slots.lastIndexWhere((id) => id != null);
    if (lastOccupied < 0) return 0;
    return lastOccupied ~/ perRow + 1;
  }

  /// Hedef moddaki sütun sayısıyla (ör. dikeyde 10) 2 sıraya sığmıyorsa,
  /// taşları sırayla en baştaki boş yuvalara toplayıp (aradaki boşlukları
  /// silerek) yeniden 2 sıraya indirir.
  void _compactSlotsIfOverflowing(int perRow) {
    final c = widget.controller;
    final slots = c.handSlots;
    if (_rowsNeeded(slots, perRow) <= 2) return;
    final ids = slots.whereType<String>().toList();
    for (var i = 0; i < ids.length; i++) {
      c.placeTile(ids[i], i);
    }
  }

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

    if (_landscape) {
      // Yatay modda üst çubuk (oda adı/Çık) tamamen kaldırıldı — dikeyde
      // kısıtlı olan yükseklik ıstaka + masaya kalsın diye. Çıkış zaten
      // sistem geri tuşuyla (PopScope/confirmLeaveOkeyGame) çalışıyor;
      // yön değiştirme düğmesi ıstakanın soluna taşındı (bkz.
      // _landscapeRackWithPhoto).
      return Column(
        children: [
          Expanded(child: _landscapeTable(context, state)),
          _turnBanner(state),
          _landscapeRackWithPhoto(context, state),
        ],
      );
    }

    // Dikey moddaki üst çubuk da kaldırıldı — yatay/dikey geçişte ıstaka
    // kimi zaman (kullanıcı yatayken taşları geniş ıstakaya yayınca) 3
    // sıraya çıkabiliyor; üst çubuğun bıraktığı yükseklik bu durumda
    // ekranın bozulmamasına yardımcı oluyor. Yön düğmesi artık masadaki
    // "Attığım" sütununun solunda (bkz. _middle).
    return Column(
      children: [
        _opponentsRow(state),
        Expanded(child: _middle(context, state)),
        _turnBanner(state),
        _handArea(context, state),
      ],
    );
  }

  Widget _orientationToggleButton() {
    return TextButton(
      onPressed: _toggleOrientation,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0x22FFD54F),
        foregroundColor: OkeyColors.okeyGlow,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(_landscape ? '⤢ Dikey' : '⤢ Yatay',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
    final discard = c.topDiscardOf(id);
    // Soldaki oyuncunun taşı buradan alınabilir (ayrı bir "Yerde" sütunu
    // yerine doğrudan fotoğrafının altındaki taştan).
    final canDraw =
        c.isMyTurn && !c.hasDrawn && state.status == 'playing';
    final canTakeHere = id == c.leftPlayerId && canDraw && discard != null;

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
          OkeyPhotoFrame(base64Photo: c.opponentPhoto(id), size: 70),
          const SizedBox(height: 4),
          const Text('attı',
              style: TextStyle(color: OkeyColors.muted, fontSize: 10)),
          const SizedBox(height: 2),
          Builder(builder: (_) {
            final tile = discard != null
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
                  );
            final visual = canTakeHere ? _dropHighlight(tile, _tileSize) : tile;
            if (!canTakeHere) return visual;
            // Dokunmak yerine sürükle: elimin/ıstakamın üzerine bırakınca
            // yerden alınır (bkz. _handArea'daki DragTarget).
            return Draggable<_DrawFromDiscardSignal>(
              data: const _DrawFromDiscardSignal(),
              feedback: Material(
                color: Colors.transparent,
                child: OkeyTileWidget(
                    tile: discard!, width: _tileSize * 1.12, isOkey: state.isOkey(discard)),
              ),
              childWhenDragging: Opacity(opacity: 0.35, child: visual),
              child: visual,
            );
          }),
          SizedBox(
            height: 12,
            child: canTakeHere
                ? const Text('almak için sürükle',
                    style:
                        TextStyle(color: OkeyColors.okeyGlow, fontSize: 9))
                : null,
          ),
        ],
      ),
    );
  }

  // ===================== Yatay mod =====================
  //
  // Rakipler gerçek bir masaya oturmuş gibi konumlanır: sıradaki oyuncu
  // solda, ondan sonraki karşıda, solumdaki oyuncu (ıskartasını
  // alabildiğim — leftPlayerId) sağda. `controller.opponents` zaten sıra
  // yönünde döndüğü için (bkz. okey_board_controller.dart), tek rakipte
  // hep karşıya, iki rakipte karşı+sağa, üç rakipte sol+karşı+sağa oturur.
  //
  // Atış taşları dönel: ben → sol → karşı → sağ → ben yönünde, herkes
  // taşını sıradaki oyuncuya bakan köşeye bırakır. Benim taşım ve
  // leftPlayerId'nin (alınabilir) taşı artık masada değil, alt çubukta
  // ıstakanın hemen solunda/sağında duruyor (bkz. _landscapeRackWithPhoto);
  // masada yalnızca "ara" oyuncuların (leftId, topId) taşları kalıyor.

  Widget _landscapeTable(BuildContext context, OkeyGameState state) {
    final c = widget.controller;
    final opps = c.opponents;
    final canDraw = c.isMyTurn && !c.hasDrawn && state.status == 'playing';
    final canDiscard = c.isMyTurn && c.hasDrawn && state.status == 'playing';

    final String? leftId = opps.length >= 3 ? opps[0] : null;
    final String? topId = opps.isEmpty ? null : opps[opps.length >= 3 ? 1 : 0];

    return Container(
      color: OkeyColors.middle,
      width: double.infinity,
      child: Stack(
        children: [
          if (topId != null)
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: Center(child: _landscapeSeat(state, topId)),
            ),
          if (leftId != null)
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(child: _landscapeSeat(state, leftId)),
            ),
          if (opps.length >= 2)
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(child: _landscapeSeat(state, opps.last)),
            ),

          // Yön değiştirme düğmesi — sağdaki oyuncunun üstünde, ekranın en
          // sağ üst köşesine yakın.
          Positioned(
            top: 4,
            right: 4,
            child: _orientationToggleButton(),
          ),

          if (leftId != null)
            _cornerPositioned(
              alignX: 0.19,
              alignY: 0.18,
              child: _landscapeOpponentDiscardSlot(state, leftId),
            ),
          if (topId != null && opps.length >= 2)
            _cornerPositioned(
              alignX: 0.81,
              alignY: 0.18,
              child: _landscapeOpponentDiscardSlot(state, topId),
            ),

          // Gösterge artık ortada değil: sola ve aşağı kaydırılmış, bilgi
          // bannerının hemen üstünde duruyor — böylece karşımdaki oyuncunun
          // koltuğuyla çakışmıyor. Deste de aynı satırda (aynı bottom
          // hizasında), sağ tarafta duruyor — ikisi de aynı yükseklikte.
          Positioned(
            left: 0,
            right: 0,
            bottom: 2,
            child: Align(
              alignment: const Alignment(-0.40, 0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _landscapeCenterPiles(context, state, canDiscard),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 2,
            child: Align(
              alignment: const Alignment(0.40, 0),
              child: _landscapeDeckPile(context, state, canDraw),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cornerPositioned({
    required double alignX,
    required double alignY,
    required Widget child,
  }) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment(alignX * 2 - 1, alignY * 2 - 1),
        child: child,
      ),
    );
  }

  Widget _landscapeSeat(OkeyGameState state, String id) {
    final c = widget.controller;
    final isTurn = state.currentTurn == id && state.status == 'playing';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
            color: isTurn ? OkeyColors.oppTurnBorder : Colors.transparent,
            width: 2),
        color: isTurn ? OkeyColors.oppTurnBg : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OkeyPhotoFrame(base64Photo: c.opponentPhoto(id), size: 70),
          const SizedBox(height: 3),
          Text(c.opponentName(id),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _landscapeDiscardTile(OkeyTile? tile, OkeyGameState state) {
    return tile != null
        ? OkeyTileWidget(tile: tile, width: _tileSize, isOkey: state.isOkey(tile))
        : _emptySlot(_tileSize);
  }

  /// Kendi son attığım taş — sürükleyip bırakınca normal atış olur (aynı
  /// [_handleDiscardDrop] mantığı, yalnızca konum köşeye taşındı).
  Widget _landscapeMyDiscardSlot(
      BuildContext context, OkeyGameState state, bool canDiscard) {
    final myDiscard = widget.controller.myLastDiscard;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => canDiscard,
      onAcceptWithDetails: (d) => _handleDiscardDrop(context, d.data),
      builder: (ctx, cand, rej) {
        final tile = _landscapeDiscardTile(myDiscard, state);
        return cand.isNotEmpty ? _dropHighlight(tile, _tileSize) : tile;
      },
    );
  }

  /// Bir rakibin son attığı taş. [takeable] true ve sıra bendeyse (henüz
  /// çekmediysem) ıstakama sürükleyerek alabilirim (bkz. _landscapeRack'ı
  /// saran DragTarget).
  Widget _landscapeOpponentDiscardSlot(OkeyGameState state, String id,
      {bool takeable = false, bool canDraw = false}) {
    final c = widget.controller;
    final discard = c.topDiscardOf(id);
    final canTakeHere = takeable && canDraw && discard != null;
    final tile = _landscapeDiscardTile(discard, state);
    final visual = canTakeHere ? _dropHighlight(tile, _tileSize) : tile;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        canTakeHere
            ? Draggable<_DrawFromDiscardSignal>(
                data: const _DrawFromDiscardSignal(),
                feedback: Material(
                  color: Colors.transparent,
                  child: OkeyTileWidget(
                      tile: discard!,
                      width: _tileSize * 1.12,
                      isOkey: state.isOkey(discard)),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: visual),
                child: visual,
              )
            : visual,
        // Sabit yükseklik: ipucu görünüp kaybolunca yerleşim zıplamasın.
        SizedBox(
          height: 13,
          child: canTakeHere
              ? const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('almak için sürükle',
                      style: TextStyle(color: OkeyColors.okeyGlow, fontSize: 9)),
                )
              : null,
        ),
      ],
    );
  }

  /// Ortak masa: yalnızca gösterge (deste artık ayrı, sağdaki boş alanda).
  Widget _landscapeCenterPiles(
      BuildContext context, OkeyGameState state, bool canDiscard) {
    return _indicatorCard(context, state, canDiscard, showOkeyLabel: false);
  }

  /// Deste — Gösterge'nin yanından ayrılıp masanın sağındaki boş alana
  /// taşındı (karşımdaki oyuncunun koltuğuyla çakışmasın diye).
  Widget _landscapeDeckPile(
      BuildContext context, OkeyGameState state, bool canDraw) {
    final deckCount = state.drawPile.length;
    return _pileColumn(
      label: 'Deste ($deckCount)',
      highlight: canDraw && deckCount > 0,
      child: _deckTile(canDraw, deckCount),
      hint: canDraw && deckCount > 0 ? 'çekmek için sürükle' : null,
    );
  }

  /// Deste taşı — [canDraw] ve deste doluyken sürüklenebilir olur (hem
  /// dikey hem yatay). Dokunmak yerine ıstakadaki istediğim boşluğa
  /// sürükleyip bırakırım (bkz. _slotCell'in çekme sinyali kabulü).
  Widget _deckTile(bool canDraw, int deckCount) {
    final visual = deckCount > 0
        ? const OkeyTileWidget(faceDown: true, width: _tileSize)
        : _emptySlot(_tileSize);
    if (!canDraw || deckCount == 0) return visual;
    return Draggable<_DrawFromStackSignal>(
      data: const _DrawFromStackSignal(),
      feedback: Material(
        color: Colors.transparent,
        child: const OkeyTileWidget(faceDown: true, width: _tileSize * 1.12),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: visual),
      child: visual,
    );
  }

  /// Son hamle bilgisi ve sıra durumu tek satırda birleşti — sıra bana
  /// gelince bu satır doğrudan "Sıra sende" yazar; ayrı bir "sıra" satırı
  /// yok. Hem yatay hem dikeyde kullanılır.
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
        text = '● Sıra sende';
      } else {
        text = '● Bir taş at';
      }
    } else if (action != null && action.type == 'discard') {
      text = '${c.opponentName(action.player)}, ${action.tile?.nameTr ?? ''} attı';
    } else {
      text = '○ Sıra: ${c.opponentName(state.currentTurn)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      color: isMyTurn ? OkeyColors.turnMine : OkeyColors.turnTheirs,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: isMyTurn ? Colors.white : OkeyColors.turnTheirsText,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// Istaka + kendi fotoğrafım aynı alt çubukta: yön düğmesi + benim son
  /// attığım taş ıstakanın solunda; leftPlayerId'nin (alınabilir) taşı
  /// fotoğrafımın üstünde, ıstakanın sağında.
  Widget _landscapeRackWithPhoto(BuildContext context, OkeyGameState state) {
    final c = widget.controller;
    final opps = c.opponents;
    final isMyTurn = c.isMyTurn;
    final canDraw = isMyTurn && !c.hasDrawn && state.status == 'playing';
    final canDiscard = isMyTurn && c.hasDrawn && state.status == 'playing';
    final myHand = c.myHand;

    return Container(
      color: OkeyColors.topbar,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Attığım taş — altında "atmak için sürükle" ipucu için sabit
          // yükseklikte bir boşluk (yön düğmesi artık burada değil, sağ üst
          // köşede — bkz. _landscapeTable). Çok az sağa kaydırılmış.
          Transform.translate(
            offset: const Offset(10, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _landscapeMyDiscardSlot(context, state, canDiscard),
                SizedBox(
                  height: 24,
                  child: canDiscard
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            'atmak için\nsürükle',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: OkeyColors.okeyGlow,
                                fontSize: 8,
                                height: 1.15),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // leftPlayerId'nin yerdeki taşını ya da desteden çektiğimi tam
          // istediğim boşluğa bırakabilmem için artık her ıstaka hücresi
          // kendi DragTarget'ı (bkz. _slotCell) — burada sarmalayan ayrı
          // bir hedefe gerek yok.
          Expanded(
            child: Center(
              child:
                  _landscapeRack(context, state, myHand, canDiscard, canDraw),
            ),
          ),
          const SizedBox(width: 8),
          if (opps.isNotEmpty)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Oyuncu 3'ün attığı taş — sola kaydırılmış ve yukarı
                // çekilmiş (banner'a ~3px kalacak kadar; fotoğraf yerinde
                // kalıyor, yalnızca taş kayıyor).
                Transform.translate(
                  offset: const Offset(-16, -9),
                  child: _landscapeOpponentDiscardSlot(state, opps.last,
                      takeable: true, canDraw: canDraw),
                ),
                const SizedBox(height: 4),
                OkeyPhotoFrame(base64Photo: c.opponentPhoto(c.selfId), size: 70),
              ],
            )
          else
            OkeyPhotoFrame(base64Photo: c.opponentPhoto(c.selfId), size: 70),
        ],
      ),
    );
  }

  /// Yatay ıstaka: 14'lük iki sıra (28 göz), taş boyutu sabit (_tileSize) —
  /// dikeydeki gibi ekrana sığdırmak için küçültülmez. Ekran yeterince
  /// genişse taşlar ortalanır; sığmazsa (dar/eski yatay ekranlar) yatay
  /// kaydırmaya düşer.
  Widget _landscapeRack(BuildContext context, OkeyGameState state,
      List<OkeyTile> myHand, bool canDiscard, bool canDraw) {
    final byId = {for (final t in myHand) t.id: t};
    const perRow = _landscapeTilesPerRow;
    const tileW = _tileSize;
    const gap = 3.0;
    final tileH = tileW * OkeyTileWidget.aspect;

    final slots = widget.controller.handSlots;
    final rows = math.max(2, _rowsNeeded(slots, perRow));

    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: gap + 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var col = 0; col < perRow; col++) ...[
                if (col > 0) const SizedBox(width: gap),
                Builder(builder: (_) {
                  final i = r * perRow + col;
                  final id = i < slots.length ? slots[i] : null;
                  return _slotCell(
                      i, id, byId[id], tileW, tileH, canDiscard, state,
                      flipOkey: true, canDraw: canDraw);
                }),
              ],
            ],
          ),
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: OkeyColors.rackDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x55000000), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final needed = perRow * tileW + (perRow - 1) * gap;
          if (constraints.maxWidth >= needed) {
            // Çerçeve içeriğin (14 sütun) gerçek genişliğine sarılsın —
            // Center burada kullanılmıyor çünkü Center, sonlu (loose de
            // olsa) genişlik kısıtında mevcut alanı doldurur; biz ise
            // dıştaki Expanded+Center ile ortalıyoruz (bkz. çağıran yer).
            return grid;
          }
          return SingleChildScrollView(
              scrollDirection: Axis.horizontal, child: grid);
        },
      ),
    );
  }

  Widget _middle(BuildContext context, OkeyGameState state) {
    final c = widget.controller;
    final isMyTurn = c.isMyTurn;
    final canDraw = isMyTurn && !c.hasDrawn && state.status == 'playing';
    final canDiscard = isMyTurn && c.hasDrawn && state.status == 'playing';
    final deckCount = state.drawPile.length;
    final myDiscard = c.myLastDiscard;

    return Container(
      color: OkeyColors.middle,
      width: double.infinity,
      child: Stack(
        children: [
          // Masa içeriği ve fotoğrafım birlikte hafifçe yukarı kaydırıldı
          // (bkz. aşağıdaki Positioned'daki bottom değeri) — topbar
          // kaldırıldıktan sonra alanın ortasında daha dengeli duruyor.
          Transform.translate(
            offset: const Offset(0, -14),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _indicatorCard(context, state, canDiscard),
                      const SizedBox(height: 16),
                      // FittedBox: dar telefonlarda orta satır taşmasın diye
                      // orantılı küçülür. Atılan+Deste ikilisi çok az sağa
                      // kaydırılmış, aralarındaki boşluk da biraz açılmış.
                      Transform.translate(
                        offset: const Offset(10, 0),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Kendi en son attığım taş — atılacak taş buraya
                              // sürüklenip bırakılır (normal atış, sıra geçer).
                              _pileColumn(
                                label: 'Atılan',
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
                              const SizedBox(width: 28),
                              _pileColumn(
                                label: 'Deste ($deckCount)',
                                highlight: canDraw && deckCount > 0,
                                child: _deckTile(canDraw, deckCount),
                                hint: canDraw && deckCount > 0
                                    ? 'çekmek için sürükle'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Kendi fotoğrafım — artık sol alt köşede, hafifçe yukarı
          // kaydırılmış (masa içeriğiyle birlikte).
          Positioned(
            left: 16,
            bottom: 30,
            child: OkeyPhotoFrame(
                base64Photo: c.opponentPhoto(c.selfId), size: 70),
          ),
          // Yön değiştirme düğmesi — fotoğrafımın eski yerine, sağ alt
          // köşeye taşındı.
          Positioned(
            right: 16,
            bottom: 30,
            child: _orientationToggleButton(),
          ),
        ],
      ),
    );
  }

  /// [showOkeyLabel] false ise sağdaki "OKEY / {renk} {sayı}" metni
  /// gizlenir — yatay modda bu bilgi artık ıstakadaki okey taşının ters
  /// (baş aşağı) durmasıyla veriliyor, ayrı bir metne gerek yok.
  Widget _indicatorCard(
      BuildContext context, OkeyGameState state, bool canDiscard,
      {bool showOkeyLabel = true}) {
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
        // Kenarlık genişliği sabit (2) — yalnızca renk değişir; aksi halde
        // sarı olunca kart büyüyüp (bottom'a sabitli olduğu için) yukarı
        // doğru genişleyip üstteki oyuncu koltuğuyla çakışıyordu.
        border: Border.all(
          color: canDiscard ? OkeyColors.okeyGlow : const Color(0x33FFFFFF),
          width: 2,
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
              // Sabit yükseklik: ipucu görünüp kaybolunca kart boyutu
              // değişmesin diye (aksi halde bunu saran FittedBox sürekli
              // yeniden ölçeklenip ekranı zıplatıyordu).
              SizedBox(
                height: 16,
                child: canDiscard
                    ? const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text('bitirmek için sürükle',
                            style: TextStyle(
                                color: OkeyColors.okeyGlow, fontSize: 10)),
                      )
                    : null,
              ),
            ],
          ),
          if (showOkeyLabel) ...[
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

  Widget _handArea(BuildContext context, OkeyGameState state) {
    final c = widget.controller;
    final isMyTurn = c.isMyTurn;
    final canDraw = isMyTurn && !c.hasDrawn && state.status == 'playing';
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
          // Solumdaki oyuncunun (leftPlayerId) yerdeki taşını ya da desteden
          // çektiğimi tam istediğim boşluğa bırakabilmem için artık her
          // ıstaka hücresi kendi DragTarget'ı (bkz. _slotCell).
          _rackWithTiles(context, state, myHand, canDiscard, canDraw),
        ],
      ),
    );
  }

  /// Elimi ıstakaya yuva-ızgarası olarak dizer. Her hücre bir bırakma
  /// hedefidir; taşı boş yuvaya bırakırsan oraya gider, eski yeri boş kalır
  /// (serbest yerleşim + boşluk bırakma). Boş yuvalar soluk gösterilir.
  Widget _rackWithTiles(BuildContext context, OkeyGameState state,
      List<OkeyTile> myHand, bool canDiscard, bool canDraw) {
    final byId = {for (final t in myHand) t.id: t};
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const gap = 3.0;
        const hPad = 8.0;
        const borderW = 2.0; // rafın kenarlığı (taşmayı önlemek için düşülür)
        // Sıra başına taş sayısı sabit (_rackTilesPerRow); taş piksel boyutu
        // bu sayıyı ekrana tam sığdıracak şekilde hesaplanır — geniş
        // ekranlarda en fazla _tileSize'a kadar büyür, dar telefonlarda
        // (Honor vb.) otomatik küçülür, sıra başına taş sayısı hep aynı kalır.
        final inner = width - hPad * 2 - borderW * 2;
        const perRow = _rackTilesPerRow;
        var tileW = (inner - (perRow - 1) * gap) / perRow;
        tileW = tileW.clamp(18.0, _tileSize);
        final tileH = tileW * OkeyTileWidget.aspect;

        final slots = widget.controller.handSlots;
        // En az 2 satır; taşlar sığmıyorsa daha fazla. Kalan hücreler boş yuva.
        final rows = math.max(2, _rowsNeeded(slots, perRow));

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
                            i, id, byId[id], tileW, tileH, canDiscard, state,
                            flipOkey: true, canDraw: canDraw);
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
  /// gösterir. Her hücre bir DragTarget'tır ve üç tür sürüklemeyi kabul eder:
  /// elimdeki bir taşı yeniden dizmek (`String`, taş kimliği), desteden
  /// çekmek ([_DrawFromStackSignal]) ya da yerden almak
  /// ([_DrawFromDiscardSignal]) — böylece çektiğim/aldığım taşı ıstakadaki
  /// istediğim boşluğa doğrudan bırakabilirim.
  /// [flipOkey] true ise okey (joker) taşı ters (baş aşağı) çizilir —
  /// hem yatay hem dikey ıstakada, hangi taşın okey olduğunu bu şekilde
  /// hatırlatıyoruz (yatayda ayrıca "OKEY: {renk} {sayı}" metni de yok).
  /// Sahte okeyler (fiziksel joker taşları, [OkeyTile.isFakeJoker]) hariç —
  /// onlar zaten ayrı görünüyor, ters çevrilmez; yalnızca göstergeye göre
  /// bu elde okey sayılan gerçek (renk+sayı) taş ters durur.
  Widget _slotCell(int index, String? tileId, OkeyTile? tile, double w,
      double h, bool canDiscard, OkeyGameState state,
      {bool flipOkey = false, bool canDraw = false}) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (d) {
        final data = d.data;
        if (data is String) return data != tileId;
        if (data is _DrawFromDiscardSignal || data is _DrawFromStackSignal) {
          return canDraw;
        }
        return false;
      },
      onAcceptWithDetails: (d) => _handleSlotDrop(d.data, index),
      builder: (ctx, cand, rej) {
        final hl = cand.isNotEmpty;
        if (tile == null) {
          return _emptyRackSlot(w, h, hl);
        }
        final isOkeyTile = state.isOkey(tile);
        final shouldFlip = flipOkey && isOkeyTile && !tile.isFakeJoker;
        Widget applyFlip(Widget child) =>
            shouldFlip ? Transform.rotate(angle: math.pi, child: child) : child;
        final tileWidget = applyFlip(OkeyTileWidget(
          tile: tile,
          width: w,
          isOkey: isOkeyTile,
          selected: tile.id == _selectedId,
          onTap: () => _onTileTap(tile, canDiscard),
        ));
        return Draggable<String>(
          data: tile.id,
          feedback: Material(
            color: Colors.transparent,
            child: applyFlip(OkeyTileWidget(
                tile: tile, width: w * 1.12, isOkey: isOkeyTile)),
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

  /// Bir ıstaka hücresine bırakılan sürüklemeyi türüne göre yönlendirir:
  /// elden gelen bir taş kimliğiyse yeniden dizer; çekme/alma sinyaliyse
  /// önce taşı çeker/alır, sonra tam bu hücreye ([targetIndex]) yerleştirir.
  Future<void> _handleSlotDrop(Object data, int targetIndex) async {
    if (data is String) {
      widget.controller.placeTile(data, targetIndex);
      return;
    }
    if (data is _DrawFromDiscardSignal) {
      await _drawThenPlace(fromDiscard: true, targetIndex: targetIndex);
    } else if (data is _DrawFromStackSignal) {
      await _drawThenPlace(fromDiscard: false, targetIndex: targetIndex);
    }
  }

  /// Desteden çeker ya da yerden alır, ardından yeni gelen taşı — hangi
  /// taşın "yeni" olduğunu çekme öncesi/sonrası eldeki taş kimliklerini
  /// karşılaştırarak bulup — bırakıldığı boşluğa taşır.
  Future<void> _drawThenPlace(
      {required bool fromDiscard, required int targetIndex}) async {
    final beforeIds = widget.controller.myHand.map((t) => t.id).toSet();
    if (fromDiscard) {
      await widget.controller.drawFromDiscard();
    } else {
      await widget.controller.drawFromStack();
    }
    if (!mounted) return;
    for (final t in widget.controller.myHand) {
      if (!beforeIds.contains(t.id)) {
        widget.controller.placeTile(t.id, targetIndex);
        break;
      }
    }
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
    final winsNormally =
        OkeyMeldSolver.isWinningHand(rest, state.okeyColor, state.okeyNumber);
    final winsAsPairs = !winsNormally &&
        OkeyMeldSolver.isPairWinningHand(rest, state.okeyColor, state.okeyNumber);
    if (rest.length != 14 || (!winsNormally && !winsAsPairs)) {
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
