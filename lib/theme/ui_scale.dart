import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Tüm ölçeklemenin dayandığı referans tasarım boyutu — yaygın bir telefon
/// ölçüsü. Ekrandaki her ölçü "bu ekranda kaç piksel" değil, "390x844'lük
/// tasarımda kaç piksel" olarak yazılır ve [computeUiScale] katsayısıyla
/// çarpılır.
const Size kUiReference = Size(390, 844);

/// Menü / kurulum ekranlarında katsayının üst sınırı. Bu ekranlarda boşluğu
/// doldurmak istemiyoruz (bkz. [uiContentMaxWidth]) — 800px genişliğinde bir
/// "Yeni Oyun Kur" butonu ya da giriş kutusu bozuk durur.
const double kMenuMaxScale = 1.15;

/// Oyun tahtalarında katsayının üst sınırı. Menüden yüksek, çünkü tahtada
/// boşluğu doldurmak *doğru*: tablette büyük kart daha okunaklı. Üst sınırı
/// yükseltmek taşma riski taşımaz — [computeUiScale] katsayıyı iki oranın
/// küçüğünden türettiği için içerik tanım gereği ekrana sığmaya devam eder;
/// sınır tamamen estetiktir.
const double kBoardMaxScale = 1.5;

/// Katsayının alt sınırı; çok dar ekranlarda arayüzün okunamayacak kadar
/// küçülmesini engeller.
const double kMinScale = 0.75;

/// Ekranın gerçek boyutunu [reference] tasarımına oranlayan TEK katsayı.
///
/// İki orandan küçüğü alınır (`min`), böylece içerik hem yatayda hem dikeyde
/// sığar. Sonuç [kMinScale] ile [maxScale] arasına sıkıştırılır.
///
/// Eskiden her bölüm kendi başına `FittedBox` ile bağımsız küçülüyordu; dar
/// ekranlarda (ör. Honor serisi) bu, parçaların birbirine göre tutarsız
/// oranda görünmesine yol açıyordu. Artık kart/fotoğraf boyutları, yazı
/// puntoları ve boşluklar hep bu tek katsayıyla ölçeklenir — tahtalar ve
/// menüler aynı formülü paylaşır, yalnızca üst sınırları farklıdır.
double computeUiScale(
  BoxConstraints c, {
  double maxScale = kMenuMaxScale,
  Size reference = kUiReference,
}) {
  final w = c.maxWidth.isFinite ? c.maxWidth : reference.width;
  final h = c.maxHeight.isFinite ? c.maxHeight : reference.height;
  return math
      .min(w / reference.width, h / reference.height)
      .clamp(kMinScale, maxScale);
}

/// Menü / kurulum ekranlarındaki içerik sütununun azami genişliği:
/// referans genişliğinin ölçeklenmiş hali.
///
/// Telefonlarda bu bir işe yaramaz — genişlik kısıtlayıcı olduğunda
/// `scale == w / 390` olur, dolayısıyla sonuç tam ekran genişliğine eşittir.
/// Yalnızca ekran oransal olarak genişken (tablet) devreye girip içeriği
/// ortada, telefon oranında bir sütun hâlinde tutar. Böylece butonlar ve
/// giriş kutuları tablette ekranı baştan başa katetmez.
double uiContentMaxWidth(double scale) => kUiReference.width * scale;

/// Menü / kurulum ekranlarının kenar boşluğu.
///
/// Tasarımdaki [horizontal] / [vertical] boşluğa ek olarak, ekran telefon
/// oranından genişse (tablet) içeriği ortada [uiContentMaxWidth] kadar bir
/// sütunda tutacak yatay boşluk ekler. Telefonda eklenen boşluk sıfırdır,
/// yani görünüm hiç değişmez.
///
/// `SingleChildScrollView`'a verildiğinde çocuğun kullanabileceği genişliği
/// daralttığı için, `width: double.infinity` olan butonlar da tablette
/// ekranı baştan başa katetmek yerine bu sütuna sığar.
EdgeInsets uiContentPadding(
  BoxConstraints c,
  double scale, {
  required double horizontal,
  required double vertical,
}) {
  final w = c.maxWidth.isFinite ? c.maxWidth : kUiReference.width;
  final extra = math.max(0.0, (w - uiContentMaxWidth(scale)) / 2);
  return EdgeInsets.symmetric(
      horizontal: horizontal + extra, vertical: vertical);
}
