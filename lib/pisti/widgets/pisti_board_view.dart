import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/player_photo_frame.dart';
import '../models/pisti_board_controller.dart';
import '../models/pisti_card.dart';
import '../../theme/ui_scale.dart';
import '../models/pisti_game_state.dart';
import '../theme/pisti_theme.dart';
import 'pisti_card_widget.dart';

/// Ekranın gerçek boyutunu referans tasarıma oranlayan TEK katsayı —
/// menü/kurulum ekranlarıyla birebir aynı formül ([computeUiScale]), yalnızca
/// üst sınır daha yüksek (bkz. [kBoardMaxScale]): menüde boşluğu doldurmak
/// istemeyiz ama tahtada doldurmak doğrudur, tablette büyük kart daha
/// okunaklıdır.
///
/// Eskiden her bölüm (masa, rakip kutuları, el) kendi başına FittedBox ile
/// küçülüyordu; dar ekranlarda (ör. Honor serisi) bu, parçaların birbirine
/// göre tutarsız oranda görünmesine yol açıyordu. Artık kart/fotoğraf
/// boyutları, yazı puntoları ve boşluklar hep bu tek katsayıyla ölçekleniyor.
double _computeScale(BoxConstraints c) =>
    computeUiScale(c, maxScale: kBoardMaxScale);

/// Pişti tahtası — `docs/pisti/game.js`'teki `renderBoard()` ile birebir
/// aynı görsel dili kullanır. Hem online (Firestore) hem de bilgisayara
/// karşı (yerel) mod bu widget'ı [PistiBoardController] üzerinden paylaşır.
class PistiBoardView extends StatelessWidget {
  final PistiBoardController controller;
  final String roomLabel;
  final VoidCallback onLeave;

  const PistiBoardView({
    super.key,
    required this.controller,
    required this.roomLabel,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        if (state == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return LayoutBuilder(
          builder: (context, constraints) => _Board(
            controller: controller,
            state: state,
            roomLabel: roomLabel,
            onLeave: onLeave,
            scale: _computeScale(constraints),
          ),
        );
      },
    );
  }
}

class _Board extends StatelessWidget {
  final PistiBoardController controller;
  final PistiGameState state;
  final String roomLabel;
  final VoidCallback onLeave;

  /// bkz. [_computeScale] — tahtadaki tüm ölçüler bununla çarpılır.
  final double scale;

  const _Board({
    required this.controller,
    required this.state,
    required this.roomLabel,
    required this.onLeave,
    required this.scale,
  });

  /// Referans tasarımdaki bir ölçüyü ([scale] ile) bu ekrana uyarlar.
  double _s(double v) => v * scale;

  bool get _collecting => state.pendingCapture != null;
  bool get _isMyTurn => controller.isMyTurn;

  @override
  Widget build(BuildContext context) {
    final pile = state.pile;
    final top = pile.isNotEmpty ? pile.last : null;
    final deckCount = state.drawPile.length;

    return Column(
      children: [
        Container(
          color: PistiColors.topbar,
          padding: EdgeInsets.symmetric(horizontal: _s(12), vertical: _s(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(roomLabel, style: TextStyle(color: PistiColors.muted, fontSize: _s(14))),
              TextButton(
                onPressed: onLeave,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0x1AFFFFFF),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: _s(16), vertical: _s(8)),
                ),
                child: Text('Çık', style: TextStyle(fontSize: _s(14))),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.all(_s(8)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < controller.opponents.length; i++) ...[
                  if (i > 0) SizedBox(width: _s(8)),
                  _OpponentTile(
                      id: controller.opponents[i],
                      controller: controller,
                      state: state,
                      scale: scale),
                ],
              ],
            ),
          ),
        ),

        Expanded(
          child: Container(
            color: PistiColors.middle,
            child: Stack(
              children: [
                // İçerik zaten tek ölçek katsayısıyla küçülüyor; FittedBox
                // yalnızca uç durumlar için emniyet payı olarak duruyor.
                // Sağdaki fotoğrafa (70px + 16px boşluk = 86px) yer açmak için
                // hafif sola kaydırılmış.
                Padding(
                  padding: EdgeInsets.only(right: _s(90)),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.all(_s(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Deste ($deckCount)',
                                style: TextStyle(color: PistiColors.pileLabel, fontSize: _s(12))),
                            SizedBox(height: _s(6)),
                            deckCount > 0
                                ? PistiCardWidget(faceDown: true, width: _s(84))
                                : _EmptySlot(width: _s(84)),
                          ],
                        ),
                        SizedBox(width: _s(22)),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Yerdeki kartlar',
                                style: TextStyle(color: PistiColors.pileLabel, fontSize: _s(12))),
                            SizedBox(height: _s(6)),
                            top != null
                                ? _TableStack(pile: pile, cardWidth: _s(84))
                                : _EmptySlot(width: _s(84)),
                            SizedBox(height: _s(10)),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: _s(12), vertical: _s(2)),
                              decoration: BoxDecoration(
                                color: PistiColors.pileCountBg,
                                borderRadius: BorderRadius.circular(_s(12)),
                              ),
                              child: Text(
                                '${pile.length} kart',
                                style: TextStyle(
                                    color: PistiColors.pileCountText, fontWeight: FontWeight.w800, fontSize: _s(14)),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: _s(22)),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Sende', style: TextStyle(color: PistiColors.pileLabel, fontSize: _s(12))),
                            SizedBox(height: _s(6)),
                            Text('${controller.wonCount(controller.selfId)} 🂠',
                                style: TextStyle(color: Colors.white, fontSize: _s(30))),
                            if (controller.pistiCountFor(controller.selfId) > 0)
                              Padding(
                                padding: EdgeInsets.only(top: _s(3)),
                                child: Text(
                                  '🔥 ${controller.pistiCountFor(controller.selfId)} pişti',
                                  style: TextStyle(
                                      color: PistiColors.pistiTag, fontSize: _s(12), fontWeight: FontWeight.w800),
                                ),
                              ),
                          ],
                        ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Kendi fotoğrafım — sağ altta, ekranın kenarına ve alttaki
                // bilgi/sıra banner'ına tam yaslanmadan hafif ayrık (ikisinden
                // de eşit boşlukla).
                Positioned(
                  right: _s(16),
                  bottom: _s(16),
                  child: PlayerPhotoFrame(
                    base64Photo: controller.opponentPhoto(controller.selfId),
                    size: _s(70),
                    borderColor: PistiColors.primary,
                    backgroundColor: PistiColors.hand,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Her zaman aynı slotta kalır (yazı yokken de boş satır olarak) —
        // aksi halde banner görünüp kaybolunca orta alan (FittedBox) sürekli
        // yeniden ölçeklenip ekranı zıplatıyordu.
        _LastActionBanner(
          action: state.status == 'playing' ? state.lastAction : null,
          playerName: state.lastAction != null
              ? controller.opponentName(state.lastAction!.player)
              : '',
          scale: scale,
        ),

        Container(
          width: double.infinity,
          padding: EdgeInsets.all(_s(10)),
          color: _isMyTurn ? PistiColors.turnMine : PistiColors.turnTheirs,
          // FittedBox: satıra sığmayan uzun metinler (2 satıra geçip
          // yükseklik değiştirmeden) küçültülerek tek satırda kalır.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _collecting
                  ? '🧹 ${controller.opponentName(state.pendingCapture!.by)} masayı topluyor...'
                  : (_isMyTurn ? '● Sıra sende — bir kart oyna' : '○ Sıra: ${controller.opponentName(state.currentTurn)}'),
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: _isMyTurn ? Colors.white : PistiColors.turnTheirsText,
                fontWeight: FontWeight.w800,
                fontSize: _s(16),
              ),
            ),
          ),
        ),

        Container(
          color: PistiColors.hand,
          padding: EdgeInsets.all(_s(12)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // SizedBox: elde hiç kart kalmadığında (yeni dağıtım beklenirken)
            // Row boş kalıp yüksekliği sıfırlanmasın diye kart yüksekliği
            // kadar sabit yer ayrılıyor.
            child: SizedBox(
              height: _s(70) * 1.4,
              child: Row(
              children: [
                for (var i = 0; i < controller.myHand.length; i++) ...[
                  if (i > 0) SizedBox(width: _s(6)),
                  PistiCardWidget(
                    card: controller.myHand[i],
                    width: _s(70),
                    dimmed: !_isMyTurn,
                    onTap: _isMyTurn ? () => _tryPlay(context, controller.myHand[i]) : null,
                  ),
                ],
              ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _tryPlay(BuildContext context, PistiCard card) async {
    if (_collecting) return;
    if (!_isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sıra sende değil.')),
      );
      return;
    }
    await controller.playCard(card);
  }
}

class _EmptySlot extends StatelessWidget {
  final double width;
  const _EmptySlot({required this.width});

  @override
  Widget build(BuildContext context) {
    // Ölçüler kart genişliğinden türetiliyor — [width] zaten ekran ölçeğiyle
    // çarpılmış geldiği için köşe yarıçapı ve yazı da onunla birlikte küçülür.
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: const Color(0x33FFFFFF),
        strokeWidth: 2,
        radius: width * 0.12,
        dashWidth: 6,
        dashGap: 4,
      ),
      child: Container(
        width: width,
        height: width * 1.4,
        alignment: Alignment.center,
        child: Text('boş',
            style: TextStyle(color: const Color(0x66FFFFFF), fontSize: width * 0.155)),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashGap;

  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashWidth,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, end.clamp(0, metric.length)), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}

/// Masadaki desteyi gösterir: en üstteki kart açık, altındakiler kapalı yığın
/// halinde hafifçe kaydırılmış olarak görünür.
class _TableStack extends StatelessWidget {
  final List<PistiCard> pile;

  /// Ekran ölçeğiyle çarpılmış kart genişliği; yığındaki kaydırma payları da
  /// buna oranla hesaplanır.
  final double cardWidth;
  const _TableStack({required this.pile, required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    final top = pile.last;
    final hidden = pile.length - 1;
    if (hidden <= 0) return PistiCardWidget(card: top, width: cardWidth);

    final dx = cardWidth * 0.119; // eski sabit: 84px kartta 10px
    final dy = cardWidth * 0.095; // eski sabit: 84px kartta 8px

    return SizedBox(
      width: cardWidth + dx,
      height: cardWidth * 1.4 + dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (hidden >= 2)
            Positioned(
              left: -dx,
              top: -dy,
              child: Transform.rotate(
                angle: -7 * math.pi / 180,
                child: PistiCardWidget(faceDown: true, width: cardWidth),
              ),
            ),
          Positioned(
            left: -dx / 2,
            top: -dy / 2,
            child: Transform.rotate(
              angle: -3.5 * math.pi / 180,
              child: PistiCardWidget(faceDown: true, width: cardWidth),
            ),
          ),
          PistiCardWidget(card: top, width: cardWidth),
        ],
      ),
    );
  }
}

class _OpponentTile extends StatelessWidget {
  final String id;
  final PistiBoardController controller;
  final PistiGameState state;
  final double scale;

  const _OpponentTile(
      {required this.id,
      required this.controller,
      required this.state,
      required this.scale});

  double _s(double v) => v * scale;

  @override
  Widget build(BuildContext context) {
    final isTurn = state.currentTurn == id;
    final count = controller.opponentCardCount(id);
    final won = controller.wonCount(id);
    final pisti = controller.pistiCountFor(id);
    final cardW = _s(34);

    return Container(
      constraints: BoxConstraints(minWidth: _s(84)),
      padding: EdgeInsets.symmetric(horizontal: _s(10), vertical: _s(6)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_s(10)),
        border: Border.all(color: isTurn ? PistiColors.oppTurnBorder : Colors.transparent, width: 2),
        color: isTurn ? PistiColors.oppTurnBg : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            controller.opponentName(id),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: _s(13)),
          ),
          SizedBox(height: _s(4)),
          PlayerPhotoFrame(
            base64Photo: controller.opponentPhoto(id),
            size: _s(70),
            borderColor: PistiColors.primary,
            backgroundColor: PistiColors.hand,
          ),
          SizedBox(height: _s(4)),
          Padding(
            padding: EdgeInsets.symmetric(vertical: _s(2)),
            child: _OverlappingOpponentCards(
              count: count,
              cardWidth: cardW,
              overlap: _s(21),
              cardBuilder: () => PistiCardWidget(faceDown: true, width: cardW),
            ),
          ),
          Text('$won', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: _s(15))),
          if (pisti > 0)
            Padding(
              padding: EdgeInsets.only(top: _s(3)),
              child: Text('🔥 $pisti pişti',
                  style: TextStyle(color: PistiColors.pistiTag, fontSize: _s(12), fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

class _LastActionBanner extends StatefulWidget {
  /// null ise gösterilecek bir şey yok — yine de aynı boş satır yüksekliği
  /// korunur (bkz. çağıran yerdeki yorum).
  final PistiLastAction? action;
  final String playerName;

  /// bkz. [_computeScale] — yazı puntoları/boşluklar bununla çarpılır.
  /// (Aşağıdaki `_pulse` ile karıştırılmamalı: o, pişti anındaki büyüyüp
  /// küçülme animasyonu.)
  final double scale;
  const _LastActionBanner(
      {required this.action, required this.playerName, required this.scale});

  @override
  State<_LastActionBanner> createState() => _LastActionBannerState();
}

class _LastActionBannerState extends State<_LastActionBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Pişti olunca banner'ı hafifçe büyütüp küçülten animasyon — ekran
  /// ölçeğiyle (widget.scale) ilgisi yok.
  late final Animation<double> _pulse;

  double _s(double v) => v * widget.scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulse = Tween<double>(begin: 1, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.action?.isPisti ?? false) {
      _runPistiPulse();
    }
  }

  @override
  void didUpdateWidget(covariant _LastActionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widget artık her zaman aynı yuvada kalıyor (bkz. çağıran yer); bu
    // yüzden yeni bir pişti olduğunda pulse animasyonunu burada tetikliyoruz
    // (eskiden widget her seferinde yeniden oluşturulduğu için initState
    // yeterliydi).
    final a = widget.action;
    if (a != null && a.isPisti && a != oldWidget.action) {
      _runPistiPulse();
    }
  }

  Future<void> _runPistiPulse() async {
    for (var i = 0; i < 2; i++) {
      if (!mounted) return;
      await _controller.forward();
      if (!mounted) return;
      await _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    if (action == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: _s(4), horizontal: _s(10)),
        child: Text(
          '',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: PistiColors.lastAction, fontSize: _s(16.5), fontWeight: FontWeight.w700),
        ),
      );
    }
    if (action.isPisti) {
      return ScaleTransition(
        scale: _pulse,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: _s(4), horizontal: _s(12)),
          padding: EdgeInsets.symmetric(vertical: _s(8), horizontal: _s(10)),
          decoration: BoxDecoration(
            color: PistiColors.pistiBannerBg,
            borderRadius: BorderRadius.circular(_s(10)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              action.isJackPisti
                  ? '🎉 ${widget.playerName} VALE PİŞTİ yaptı! (+15)'
                  : '🎉 ${widget.playerName} PİŞTİ yaptı! (${action.card.nameTr})',
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: PistiColors.pistiBannerText,
                fontSize: _s(17),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _s(4), horizontal: _s(10)),
      // FittedBox: satıra sığmayan uzun metinler (2 satıra geçip yükseklik
      // değiştirmeden) küçültülerek tek satırda kalır.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: RichText(
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.clip,
          text: TextSpan(
            style: TextStyle(
              color: PistiColors.lastAction,
              fontSize: _s(16.5),
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(text: '${widget.playerName} '),
              TextSpan(
                text: action.card.nameTr,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              TextSpan(
                text: action.captured ? ' oynadı — yaktı! 🔥' : ' oynadı',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rakip kartlarını web'deki `margin-left: -21px` ile aynı şekilde üst üste
/// bindirir. Flutter'da negatif padding yasak olduğu için Stack kullanılır.
class _OverlappingOpponentCards extends StatelessWidget {
  final int count;
  final double cardWidth;
  final double overlap;
  final Widget Function() cardBuilder;

  const _OverlappingOpponentCards({
    required this.count,
    required this.cardWidth,
    required this.overlap,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final n = math.min(count, 4);
    if (n <= 0) return const SizedBox.shrink();
    final step = cardWidth - overlap;
    final height = cardWidth * 1.4;
    return SizedBox(
      width: cardWidth + (n - 1) * step,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < n; i++)
            Positioned(left: i * step, child: cardBuilder()),
        ],
      ),
    );
  }
}
