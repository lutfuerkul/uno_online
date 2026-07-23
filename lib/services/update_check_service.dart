import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Bir sürüm kontrolü sonucu.
class UpdateCheckResult {
  final bool updateAvailable;
  final int currentBuildNumber;
  final int latestBuildNumber;

  const UpdateCheckResult({
    required this.updateAvailable,
    required this.currentBuildNumber,
    required this.latestBuildNumber,
  });
}

/// Yüklü uygulamanın sürümünü, her `main`'e giden derlemede otomatik
/// güncellenen `latest_version.json` dosyasıyla (GitHub'daki ham içerik)
/// karşılaştırır. Play Store olmadığı için güncelleme kontrolünü kendimiz
/// yapıyoruz — internet yoksa ya da kontrol başarısız olursa sessizce
/// vazgeçilir (uygulamayı engellemez).
class UpdateCheckService {
  static const _versionUrl =
      'https://raw.githubusercontent.com/lutfuerkul/uno_online/main/latest_version.json';

  static Future<UpdateCheckResult?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;

      final res = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = (data['buildNumber'] as num?)?.toInt();
      if (latest == null) return null;

      return UpdateCheckResult(
        updateAvailable: latest > current,
        currentBuildNumber: current,
        latestBuildNumber: latest,
      );
    } catch (_) {
      return null;
    }
  }
}
