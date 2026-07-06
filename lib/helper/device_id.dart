import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable per-install device identifier used for the backend
/// device-whitelist check.
///
/// Sent as `mac_address` in the `POST /login` body and as the
/// `x-mac-address` header on every authenticated request thereafter.
///
/// Approach: a random UUID v4 generated once on first call and persisted
/// in `SharedPreferences`. Chosen over `device_info_plus`
/// `androidId`/`identifierForVendor` because:
///  - No new native-code dependency.
///  - Behavior is identical across Android, iOS, desktop, and web —
///    one code path, one identifier lifecycle.
///  - The only tradeoff (resets on app data clear / reinstall) is
///    acceptable given the whitelist is admin-managed and re-approval
///    is expected in those cases.
class DeviceId {
  static const _key = 'device_id_v1';

  static String? _cached;

  /// Returns the persisted device identifier, generating and storing
  /// one on first call. Subsequent calls return the cached in-memory
  /// value without hitting `SharedPreferences` again.
  static Future<String> get() async {
    final cached = _cached;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      id = _randomUuidV4();
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }

  /// Reads the identifier synchronously if it's already cached — useful
  /// for UI paths that ran [get] earlier and just need to redisplay.
  /// Returns `null` if [get] has not been awaited yet in this session.
  static String? peek() => _cached;

  /// Test-only reset. Not used in production paths.
  static void debugReset() {
    _cached = null;
  }
}

String _randomUuidV4() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

  // Set the version (4) and variant (RFC 4122) bits.
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;

  final hex = bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
