import 'package:ezbiz/models/session_info.dart';

/// Payload returned by `POST /login` with HTTP 409 when the user has
/// reached their comp_code's concurrent-device-login limit.
///
/// Backend shape:
/// ```
/// {
///   "message": "Device login limit reached (2). ...",
///   "limit": 2,
///   "active_sessions": [ SessionInfo, ... ]
/// }
/// ```
class DeviceLimitError {
  final String message;
  final int? limit;
  final List<SessionInfo> activeSessions;

  const DeviceLimitError({
    required this.message,
    required this.limit,
    required this.activeSessions,
  });

  factory DeviceLimitError.fromJson(Map<String, dynamic> json) {
    final raw = (json['active_sessions'] as List?) ?? const [];
    final sessions = raw
        .whereType<Map>()
        .map<SessionInfo>(
          (e) => SessionInfo.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();

    return DeviceLimitError(
      message:
          (json['message'] as String?) ?? 'Device login limit reached.',
      limit: (json['limit'] as num?)?.toInt(),
      activeSessions: sessions,
    );
  }
}
