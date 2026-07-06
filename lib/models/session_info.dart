/// A single active login session.
///
/// Returned in three places by the backend:
///  - the successful `POST /login` response (`session` field),
///  - the 409 `active_sessions[]` list on device-limit rejection,
///  - `GET /my-sessions` `sessions[]`.
///
/// `expires_at` is only present on the successful login `session` payload;
/// other endpoints omit it, hence nullable.
class SessionInfo {
  final String sessionId;
  final String deviceLabel;
  final String userAgent;
  final String ipAddress;
  final DateTime? issuedAt;
  final DateTime? lastActive;
  final DateTime? expiresAt;

  const SessionInfo({
    required this.sessionId,
    required this.deviceLabel,
    required this.userAgent,
    required this.ipAddress,
    this.issuedAt,
    this.lastActive,
    this.expiresAt,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    final label = (json['device_label'] ?? '').toString().trim();
    return SessionInfo(
      sessionId: (json['session_id'] ?? '').toString(),
      deviceLabel: label.isEmpty ? 'Unknown device' : label,
      userAgent: (json['user_agent'] ?? '').toString(),
      ipAddress: (json['ip_address'] ?? '').toString(),
      issuedAt: _parseDate(json['issued_at']),
      lastActive: _parseDate(json['last_active']),
      expiresAt: _parseDate(json['expires_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
