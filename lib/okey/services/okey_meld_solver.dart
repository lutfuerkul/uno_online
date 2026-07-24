import '../models/okey_tile.dart';

/// Okey el (per) çözümleyicisi: bir taş kümesinin geçerli gruplara (perlere)
/// bölünüp bölünemeyeceğini belirler.
///
/// Geçerli grup:
///  - Seri (run): aynı renkten, ardışık sayılarda 3+ taş. 1 sayısı hem en
///    altta (1-2-3) hem de 13'ten sonra (12-13-1) kullanılabilir.
///  - Grup (set): aynı sayıda, farklı renklerden 3 ya da 4 taş.
///
/// Okey (joker) iki türlüdür:
///  - Göstergeyle aynı renkte, bir büyük sayıdaki **gerçek** taş: herhangi bir
///    taşın yerini tutabilen gerçek bir jokerdir (evrensel wild).
///  - **Sahte okey**: gerçek gibi kullanılamaz; yalnızca elin okey taşının
///    (rengi+sayısı) yerine, o taşın ekstra bir kopyası gibi geçer.
///
/// Bölümleme, en küçük taşı "soyarak" (peel) ve onu içerebilecek tüm grup
/// biçimlerini deneyerek yapılır. Bir grup için bir yuvaya karar verildiğinde
/// gerçek taş varsa o kullanılır, yoksa joker harcanır — bu greedy seçim
/// bütünlük açısından güvenlidir (kanıt: bir jokerle gerçek taşın rolleri
/// gruplar arasında her zaman takas edilebilir), bu yüzden yalnızca grup
/// biçimi (seri/set, uzunluk, hangi renkler) üzerinde dallanmak yeterlidir.
class OkeyMeldSolver {
  static const int _colors = 4;
  static const int _numbers = 13;

  /// Taşları sayaç dizisine ve evrensel joker sayısına ayırır. Sahte okeyler
  /// evrensel joker havuzuna değil, doğrudan (okeyColor, okeyNumber)
  /// yuvasına gerçek bir taş gibi eklenir — yalnızca göstergeyle aynı renkte
  /// bir büyük sayıdaki **gerçek** taş evrensel jokerdir.
  static (List<int>, int) _classify(
    List<OkeyTile> tiles,
    OkeyColor okeyColor,
    int okeyNumber,
  ) {
    final counts = List<int>.filled(_colors * _numbers, 0);
    var wilds = 0;
    for (final t in tiles) {
      if (t.isFakeJoker) {
        counts[okeyColor.index * _numbers + (okeyNumber - 1)]++;
      } else if (t.color == okeyColor && t.number == okeyNumber) {
        wilds++;
      } else {
        counts[t.color.index * _numbers + (t.number - 1)]++;
      }
    }
    return (counts, wilds);
  }

  /// 14 taş tam olarak geçerli gruplara bölünüyor mu (el açılabilir mi)?
  static bool isWinningHand(
    List<OkeyTile> tiles,
    OkeyColor okeyColor,
    int okeyNumber,
  ) {
    if (tiles.length != 14) return false;
    final (counts, wilds) = _classify(tiles, okeyColor, okeyNumber);
    return _canPartition(counts, wilds, <String, bool>{});
  }

  /// 14 taş "çifte" (7 aynı renk+sayı çift) biçiminde mi — normal seri/set
  /// bölünmesinden ayrı, alternatif bir bitiş şekli.
  ///
  /// Kurallar:
  ///  - Her çift, aynı renk+sayıda iki (gerçek) taştır.
  ///  - Gerçek okey (evrensel joker) tek başına kalan herhangi bir sıradan
  ///    taşla eşleşip onu çift yapabilir (ya da iki gerçek okey birbiriyle
  ///    çift olur — zaten aynı renk+sayıdadırlar).
  ///  - Sahte okey sıradan bir taşla eşleşemez; yalnızca diğer sahte okeyle
  ///    ya da gerçek okeyle çift sayılır.
  static bool isPairWinningHand(
    List<OkeyTile> tiles,
    OkeyColor okeyColor,
    int okeyNumber,
  ) {
    if (tiles.length != 14) return false;

    final fakeCount = tiles.where((t) => t.isFakeJoker).length;
    final wildCount = tiles
        .where((t) =>
            !t.isFakeJoker && t.color == okeyColor && t.number == okeyNumber)
        .length;

    final counts = <int, int>{};
    for (final t in tiles) {
      if (t.isFakeJoker) continue;
      if (t.color == okeyColor && t.number == okeyNumber) continue;
      final key = t.color.index * _numbers + (t.number - 1);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    var leftovers = 0;
    for (final n in counts.values) {
      if (n.isOdd) leftovers++;
    }

    // Sıradan tek kalan taşlar yalnızca gerçek okeyle eşleşebilir.
    if (wildCount < leftovers) return false;
    final remainingWilds = wildCount - leftovers;

    // Kalan gerçek okeyler ve sahte okeyler artık birbiriyle serbestçe
    // eşleşebilir (sahte+sahte, sahte+gerçek okey, gerçek okey+gerçek okey);
    // toplamlarının çift olması yeterli.
    return (fakeCount + remainingWilds).isEven;
  }

  /// 15 taştan birini atarak el açılabiliyorsa (normal ya da çifte),
  /// atılacak taşı döndürür. [preferOkey] true ise (çifte puan için)
  /// mümkünse okey atan bir bitiş seçilir. Açılamıyorsa null.
  static OkeyTile? winningDiscard(
    List<OkeyTile> tiles,
    OkeyColor okeyColor,
    int okeyNumber, {
    bool preferOkey = false,
  }) {
    if (tiles.length != 15) return null;
    bool isRealOkey(OkeyTile t) =>
        !t.isFakeJoker && t.color == okeyColor && t.number == okeyNumber;
    OkeyTile? fallback;
    // Aynı taştan birden fazla varsa gereksiz tekrar denemeyi önlemek için
    // denenen taş imzalarını izleriz.
    final tried = <String>{};
    for (final candidate in tiles) {
      final sig = candidate.isFakeJoker
          ? 'fake'
          : isRealOkey(candidate)
              ? 'okey'
              : '${candidate.color.index}-${candidate.number}';
      if (!tried.add(sig)) continue;
      final rest = <OkeyTile>[];
      var removed = false;
      for (final t in tiles) {
        if (!removed && t.id == candidate.id) {
          removed = true;
          continue;
        }
        rest.add(t);
      }
      if (isWinningHand(rest, okeyColor, okeyNumber) ||
          isPairWinningHand(rest, okeyColor, okeyNumber)) {
        if (isRealOkey(candidate)) {
          if (preferOkey) return candidate;
          fallback ??= candidate;
        } else {
          if (!preferOkey) return candidate;
          fallback ??= candidate;
        }
      }
    }
    return fallback;
  }

  /// Bot sezgisi: gruplara yerleştirilebilecek en fazla taş sayısı (kaplanan).
  /// Kalan = boşta taş. Küçük değer = daha iyi el.
  static int maxCovered(
    List<OkeyTile> tiles,
    OkeyColor okeyColor,
    int okeyNumber,
  ) {
    final (counts, wilds) = _classify(tiles, okeyColor, okeyNumber);
    return _bestCover(counts, wilds, <String, int>{});
  }

  /// Kazanan bir elin gerçek grup bölünmesini bulur — jokerin (varsa) hangi
  /// taşın yerine kullanıldığını göstermek için (el bitiş ekranı). Her
  /// grup, taşların gerçek sırasıyla (seri: küçükten büyüğe, joker doğru
  /// konumda) bir liste olarak döner. El geçerli değilse null.
  static List<List<OkeyTile>>? solveMelds(
    List<OkeyTile> tiles,
    OkeyColor okeyColor,
    int okeyNumber,
  ) {
    if (tiles.length != 14) return null;
    final buckets = List<List<OkeyTile>>.generate(
        _colors * _numbers, (_) => <OkeyTile>[]);
    final wildTiles = <OkeyTile>[];
    for (final t in tiles) {
      if (t.isFakeJoker) {
        buckets[okeyColor.index * _numbers + (okeyNumber - 1)].add(t);
      } else if (t.color == okeyColor && t.number == okeyNumber) {
        wildTiles.add(t);
      } else {
        buckets[t.color.index * _numbers + (t.number - 1)].add(t);
      }
    }
    final out = <List<OkeyTile>>[];
    if (_solveTiles(buckets, wildTiles, out)) {
      return out.reversed.toList();
    }
    return null;
  }

  static bool _solveTiles(
    List<List<OkeyTile>> buckets,
    List<OkeyTile> wildTiles,
    List<List<OkeyTile>> out,
  ) {
    final idx = _firstPresentBuckets(buckets);
    if (idx == -1) {
      if (wildTiles.isEmpty) return true;
      if (wildTiles.length >= 3) {
        out.add(List<OkeyTile>.of(wildTiles));
        return true;
      }
      return false;
    }
    return _forEachGroupTiles(buckets, wildTiles, idx, (nb, nw, meld) {
      if (_solveTiles(nb, nw, out)) {
        out.add(meld);
        return true;
      }
      return false;
    });
  }

  static List<List<OkeyTile>> _cloneBuckets(List<List<OkeyTile>> b) =>
      [for (final l in b) List<OkeyTile>.of(l)];

  static int _firstPresentBuckets(List<List<OkeyTile>> b) {
    for (var i = 0; i < b.length; i++) {
      if (b[i].isNotEmpty) return i;
    }
    return -1;
  }

  static bool _valuePresentTiles(
      List<List<OkeyTile>> buckets, int color, int value) {
    final number = _valueToNumber(value);
    return buckets[color * _numbers + (number - 1)].isNotEmpty;
  }

  /// [_forEachGroup]'un taş nesnelerini (kimliklerini koruyarak) izleyen
  /// karşılığı — yalnızca el bitiş ekranındaki [solveMelds] için kullanılır.
  static bool _forEachGroupTiles(
    List<List<OkeyTile>> buckets,
    List<OkeyTile> wildTiles,
    int idx,
    bool Function(List<List<OkeyTile>> newBuckets, List<OkeyTile> newWilds,
            List<OkeyTile> meld)
        visit,
  ) {
    final color = idx ~/ _numbers;
    final number = idx % _numbers + 1;
    final wilds = wildTiles.length;

    // --- SETLER ---
    final present = <int>[];
    for (var c = 0; c < _colors; c++) {
      if (c == color) continue;
      if (buckets[c * _numbers + (number - 1)].isNotEmpty) present.add(c);
    }
    for (var size = 3; size <= 4; size++) {
      final need = size - 1;
      final maxFromPresent = need < present.length ? need : present.length;
      final minFromPresent = need - wilds < 0 ? 0 : need - wilds;
      for (var take = minFromPresent; take <= maxFromPresent; take++) {
        final wildsUsed = need - take;
        if (wildsUsed < 0 || wildsUsed > wilds) continue;
        final stop = _forEachSubset(present, take, (subset) {
          final nb = _cloneBuckets(buckets);
          final meld = <OkeyTile>[nb[idx].removeLast()];
          for (final c in subset) {
            meld.add(nb[c * _numbers + (number - 1)].removeLast());
          }
          final nw = List<OkeyTile>.of(wildTiles);
          for (var i = 0; i < wildsUsed; i++) {
            meld.add(nw.removeLast());
          }
          return visit(nb, nw, meld);
        });
        if (stop) return true;
      }
    }

    // --- SERİLER ---
    final values = <int>[number];
    if (number == 1) values.add(14);
    for (final tValue in values) {
      for (var lo = 1; lo <= tValue; lo++) {
        for (var hi = tValue; hi <= 14; hi++) {
          final len = hi - lo + 1;
          if (len < 3 || len > 13) continue;
          var wildsUsed = 0;
          for (var v = lo; v <= hi; v++) {
            if (v == tValue) continue;
            if (!_valuePresentTiles(buckets, color, v)) wildsUsed++;
          }
          if (wildsUsed > wilds) continue;
          final nb = _cloneBuckets(buckets);
          final nw = List<OkeyTile>.of(wildTiles);
          final meld = List<OkeyTile?>.filled(hi - lo + 1, null);
          meld[tValue - lo] = nb[idx].removeLast();
          for (var v = lo; v <= hi; v++) {
            if (v == tValue) continue;
            final n = _valueToNumber(v);
            if (_valuePresentTiles(buckets, color, v)) {
              meld[v - lo] = nb[color * _numbers + (n - 1)].removeLast();
            } else {
              meld[v - lo] = nw.removeLast();
            }
          }
          if (visit(nb, nw, meld.cast<OkeyTile>())) return true;
        }
      }
    }
    return false;
  }

  static String _key(List<int> counts, int wilds) {
    final sb = StringBuffer();
    for (final c in counts) {
      sb.write(c);
    }
    sb.write('|');
    sb.write(wilds);
    return sb.toString();
  }

  static int _firstPresent(List<int> counts) {
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] > 0) return i;
    }
    return -1;
  }

  static bool _canPartition(List<int> counts, int wilds, Map<String, bool> memo) {
    final idx = _firstPresent(counts);
    if (idx == -1) {
      // Yalnızca jokerler kaldı: 0 ya da 3+ ise kendi başına bir grup olur.
      return wilds == 0 || wilds >= 3;
    }
    final key = _key(counts, wilds);
    final cached = memo[key];
    if (cached != null) return cached;

    var result = false;
    _forEachGroup(counts, wilds, idx, (newCounts, newWilds) {
      if (!result && _canPartition(newCounts, newWilds, memo)) {
        result = true;
      }
      return result; // true → dallanmayı durdur
    });

    memo[key] = result;
    return result;
  }

  static int _bestCover(List<int> counts, int wilds, Map<String, int> memo) {
    final idx = _firstPresent(counts);
    if (idx == -1) {
      return wilds >= 3 ? wilds : 0;
    }
    final key = _key(counts, wilds);
    final cached = memo[key];
    if (cached != null) return cached;

    // Seçenek 1: en küçük taşı boşta bırak.
    final skipped = List<int>.of(counts);
    skipped[idx]--;
    var best = _bestCover(skipped, wilds, memo);

    // Seçenek 2: bir gruba yerleştir.
    _forEachGroup(counts, wilds, idx, (newCounts, newWilds) {
      final used = _totalTiles(counts, wilds) - _totalTiles(newCounts, newWilds);
      final cover = used + _bestCover(newCounts, newWilds, memo);
      if (cover > best) best = cover;
      return false; // tümünü dene
    });

    memo[key] = best;
    return best;
  }

  static int _totalTiles(List<int> counts, int wilds) {
    var sum = wilds;
    for (final c in counts) {
      sum += c;
    }
    return sum;
  }

  /// [idx] konumundaki (en küçük mevcut) taşı içeren tüm geçerli grupları
  /// üretir ve her biri için [visit]'i çağırır — grubun tükettiği taşlar
  /// düşülmüş yeni sayaç/joker durumuyla. [visit] true dönerse erken durur.
  static void _forEachGroup(
    List<int> counts,
    int wilds,
    int idx,
    bool Function(List<int> newCounts, int newWilds) visit,
  ) {
    final color = idx ~/ _numbers;
    final number = idx % _numbers + 1;

    // --- SETLER (aynı sayı, farklı renk) ---
    final present = <int>[]; // idx dışındaki, aynı sayıda mevcut renkler
    for (var c = 0; c < _colors; c++) {
      if (c == color) continue;
      if (counts[c * _numbers + (number - 1)] > 0) present.add(c);
    }
    for (var size = 3; size <= 4; size++) {
      final need = size - 1; // idx dışındaki taş sayısı
      final maxFromPresent = need < present.length ? need : present.length;
      final minFromPresent = need - wilds < 0 ? 0 : need - wilds;
      for (var take = minFromPresent; take <= maxFromPresent; take++) {
        final wildsUsed = need - take;
        if (wildsUsed < 0 || wildsUsed > wilds) continue;
        // present içinden `take` renkli alt küme seç.
        _forEachSubset(present, take, (subset) {
          final nc = List<int>.of(counts);
          nc[idx]--;
          for (final c in subset) {
            nc[c * _numbers + (number - 1)]--;
          }
          return visit(nc, wilds - wildsUsed);
        });
      }
    }

    // --- SERİLER (aynı renk, ardışık sayı) ---
    // 1 sayısı hem değer 1 hem değer 14 (13'ten sonra) olabilir.
    final values = <int>[number];
    if (number == 1) values.add(14);
    for (final tValue in values) {
      // lo: tValue'ye kadar (altta joker doldurma ile).
      for (var lo = 1; lo <= tValue; lo++) {
        for (var hi = tValue; hi <= 14; hi++) {
          final len = hi - lo + 1;
          if (len < 3 || len > 13) continue;
          // [lo,hi] aralığındaki her değer için joker gereksinimini hesapla.
          var wildsUsed = 0;
          for (var v = lo; v <= hi; v++) {
            if (v == tValue) continue; // idx taşı buraya konur
            if (!_valuePresent(counts, color, v)) wildsUsed++;
          }
          if (wildsUsed > wilds) continue;
          final nc = List<int>.of(counts);
          nc[idx]--;
          for (var v = lo; v <= hi; v++) {
            if (v == tValue) continue;
            if (_valuePresent(counts, color, v)) {
              nc[color * _numbers + (_valueToNumber(v) - 1)]--;
            }
          }
          if (visit(nc, wilds - wildsUsed)) return;
        }
      }
    }
  }

  static int _valueToNumber(int value) => value == 14 ? 1 : value;

  static bool _valuePresent(List<int> counts, int color, int value) {
    final number = _valueToNumber(value);
    return counts[color * _numbers + (number - 1)] > 0;
  }

  /// [items] içinden [k] elemanlı tüm alt kümeleri üretir. [visit] true
  /// dönerse erken durur; herhangi biri true dönerse true döner.
  static bool _forEachSubset(
    List<int> items,
    int k,
    bool Function(List<int> subset) visit,
  ) {
    final n = items.length;
    if (k == 0) return visit(const []);
    if (k > n) return false;
    final indices = List<int>.generate(k, (i) => i);
    while (true) {
      final subset = [for (final i in indices) items[i]];
      if (visit(subset)) return true;
      // sonraki kombinasyon
      var i = k - 1;
      while (i >= 0 && indices[i] == n - k + i) {
        i--;
      }
      if (i < 0) break;
      indices[i]++;
      for (var j = i + 1; j < k; j++) {
        indices[j] = indices[j - 1] + 1;
      }
    }
    return false;
  }
}
