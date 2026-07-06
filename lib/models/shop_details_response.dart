/// Response envelope for `POST /shopdetails`.
///
/// Backend shape:
/// ```
/// { "total": 137, "page": 1, "limit": 20, "totalPages": 7, "data": [ ... ] }
/// ```
///
/// Legacy responses (pre-pagination) returned either a bare array or
/// `{ details: [...] }` — [ShopDetailsResponse.fromJson] tolerates both so
/// callers don't need branchy parsing.
class ShopDetailsResponse {
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final List<Map<String, dynamic>> data;

  const ShopDetailsResponse({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.data,
  });

  factory ShopDetailsResponse.fromJson(dynamic json) {
    List<Map<String, dynamic>> items = const [];
    int total = 0;
    int page = 1;
    int limit = 0;
    int totalPages = 1;

    if (json is List) {
      items = json
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
      total = items.length;
    } else if (json is Map<String, dynamic>) {
      total = (json['total'] as num?)?.toInt() ?? 0;
      page = (json['page'] as num?)?.toInt() ?? 1;
      limit = (json['limit'] as num?)?.toInt() ?? 0;
      totalPages = (json['totalPages'] as num?)?.toInt() ?? 1;

      final raw = json['data'] ?? json['details'] ?? json['items'];
      if (raw is List) {
        items = raw
            .whereType<Map>()
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    return ShopDetailsResponse(
      total: total,
      page: page,
      limit: limit,
      totalPages: totalPages,
      data: items,
    );
  }
}
