import 'package:shared_preferences/shared_preferences.dart';

import 'room_import_limit_policy.dart';

/// 楽天 API 429 後の ROOM メタ補完クールダウン（端末ローカル）。
abstract final class RoomImportEnrichmentCooldownStore {
  static const String _keyUntilMs = 'room_import_enrich_rate_limit_until_ms';

  static Future<DateTime?> cooldownUntil() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_keyUntilMs) ?? 0;
    if (v <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(v);
  }

  static Future<bool> isInCooldown() async {
    final u = await cooldownUntil();
    if (u == null) return false;
    return DateTime.now().isBefore(u);
  }

  static Future<void> armAfterRateLimit429() async {
    final p = await SharedPreferences.getInstance();
    final until = DateTime.now().add(
      Duration(minutes: RoomImportLimitPolicy.enrichCooldownAfter429Minutes),
    );
    await p.setInt(_keyUntilMs, until.millisecondsSinceEpoch);
  }
}
