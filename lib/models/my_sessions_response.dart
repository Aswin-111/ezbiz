import 'package:ezbiz/models/session_info.dart';

/// Response envelope for `GET /my-sessions`.
///
/// Backend shape:
/// ```
/// { "limit": 2, "active_count": 1, "sessions": [ SessionInfo, ... ] }
/// ```
class MySessionsResponse {
  final int? limit;
  final int activeCount;
  final List<SessionInfo> sessions;

  const MySessionsResponse({
    required this.limit,
    required this.activeCount,
    required this.sessions,
  });

  factory MySessionsResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['sessions'] as List?) ?? const [];
    final sessions = raw
        .whereType<Map>()
        .map<SessionInfo>(
          (e) => SessionInfo.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();

    return MySessionsResponse(
      limit: (json['limit'] as num?)?.toInt(),
      activeCount: (json['active_count'] as num?)?.toInt() ?? sessions.length,
      sessions: sessions,
    );
  }
}
