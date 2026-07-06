import 'dart:convert';
import 'package:ezbiz/pages/order_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:ezbiz/widgets/list_loading.dart';
import 'package:ezbiz/helper/helper.dart';
import 'package:ezbiz/helper/responsive_page_size_mixin.dart';
import 'package:ezbiz/Consts/consts.dart';
import 'package:intl/intl.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({Key? key}) : super(key: key);

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage>
    with WidgetsBindingObserver, ResponsivePageSizeMixin<OrderHistoryPage> {
  @override
  double get pageCardHeight => 135;
  @override
  double get pageOverhead => 240;
  @override
  int get pageLimitMin => 5;
  @override
  int get pageLimitMax => 20;

  // Filters
  DateTime? _fromDate;
  DateTime? _toDate;
  String _status = "ALL"; // ALL | N | Y

  // Data
  final List<Map<String, dynamic>> _orders = [];

  // Pagination
  int _page = 1;
  int _limit = 10;
  int _total = 0;
  int _totalPages = 1;
  bool _hasMore = true;

  // Subtotal
  double _subtotalTrxTotal = 0;
  double _subtotalTrxNet = 0;
  int _subtotalCount = 0;

  // Loading
  bool _isInitialLoading = true;
  bool _isPageLoading = false;

  // Scroll
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _moneyFormat = NumberFormat('#,##0.##');

  String _formatMoney(dynamic value) {
    final n =
        value is num
            ? value.toDouble()
            : double.tryParse(value.toString()) ?? 0;
    return _moneyFormat.format(n);
  }

  Widget _modernStatPill({
    required String label,
    required String value,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: fg.withOpacity(0.75),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchNextPage();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _limit = computeInitialLimit();
      attachResponsivePageSize();
      _refresh();
    });
  }

  @override
  void onPageLimitChanged(int newLimit) {
    if (!mounted) return;
    setState(() => _limit = newLimit);
    _refresh();
  }

  @override
  void dispose() {
    detachResponsivePageSize();
    _scrollController.dispose();
    super.dispose();
  }

  // -------- Helpers --------
  String _fmt(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "${d.year}-$mm-$dd";
  }

  Uri _buildUri({required int page}) {
    final qp = <String, String>{
      "page": page.toString(),
      "limit": _limit.toString(),
    };

    if (_fromDate != null) qp["from"] = _fmt(_fromDate!);
    if (_toDate != null) qp["to"] = _fmt(_toDate!);

    if (_status == "N" || _status == "Y") {
      qp["status"] = _status;
    }

    return Uri.parse("$baseUrl/order-reports").replace(queryParameters: qp);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // -------- Fetch --------
  Future<void> _refresh() async {
    setState(() {
      _isInitialLoading = true;
      _isPageLoading = false;

      _orders.clear();
      _page = 1;
      _total = 0;
      _totalPages = 1;
      _hasMore = true;

      _subtotalTrxTotal = 0;
      _subtotalTrxNet = 0;
      _subtotalCount = 0;
    });

    await _fetchPage(page: 1);

    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _fetchNextPage() async {
    if (_isInitialLoading || _isPageLoading || !_hasMore) return;
    if (_page >= _totalPages) {
      setState(() => _hasMore = false);
      return;
    }
    await _fetchPage(page: _page + 1);
  }

  Future<void> _fetchPage({required int page}) async {
    try {
      setState(() => _isPageLoading = true);

      final headers = await authHeaders();
      final uri = _buildUri(page: page);

      final res = await http.get(uri, headers: headers);

      if (res.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(res.body);
        print("Data from orders ${jsonData}");
        final pagination =
            (jsonData["pagination"] as Map?)?.cast<String, dynamic>() ?? {};
        final subtotal =
            (jsonData["subtotal"] as Map?)?.cast<String, dynamic>() ?? {};

        final List<dynamic> data = (jsonData["data"] as List?) ?? [];

        final List<Map<String, dynamic>> newOrders =
            data.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        setState(() {
          _page = (pagination["page"] ?? page) as int;
          _total = (pagination["total"] ?? _total) as int;
          _totalPages = (pagination["totalPages"] ?? _totalPages) as int;

          _subtotalTrxTotal = (subtotal["trx_total"] ?? 0).toDouble();
          _subtotalTrxNet = (subtotal["trx_netamount"] ?? 0).toDouble();
          _subtotalCount = (subtotal["count"] ?? 0) as int;

          _orders.addAll(newOrders);

          _hasMore = _page < _totalPages;
        });
      } else if (res.statusCode == 401) {
        clearAuthAndNavigateToLogin();
        return;
      } else {
        _showSnack("Failed: ${res.statusCode} - ${res.body}");
      }
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => _isPageLoading = false);
    }
  }

  // -------- UI actions --------
  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _fromDate = picked;
      if (_toDate != null && _toDate!.isBefore(picked)) {
        _toDate = null;
      }
    });

    await _refresh();
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final initial = _toDate ?? _fromDate ?? now;
    final first = _fromDate ?? DateTime(2000);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() => _toDate = picked);
    await _refresh();
  }

  Future<void> _clearDates() async {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    await _refresh();
  }

  Future<void> _setStatus(String v) async {
    setState(() => _status = v);
    await _refresh();
  }

  // -------- Widgets --------
  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: selected ? Color(0xFF6C63FF) : Color(0xFFEEEDFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Color(0xFF6C63FF),
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }

  Widget _subtotalCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6C63FF).withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Summary",
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Color(0xFFEEEDFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_subtotalCount Orders',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  "Total Amount",
                  "₹${_formatMoney(_subtotalTrxTotal)}",
                  Color(0xFFEEEDFF),
                  Color(0xFF6C63FF),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _statCard(
                  "Net Amount",
                  "₹${_formatMoney(_subtotalTrxNet)}",
                  Color(0xFFE8F5E9),
                  Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            "Page $_page of $_totalPages • Total $_total orders",
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color bgColor, Color textColor) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15.sp,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    if (s == "Y") return Color(0xFF4CAF50);
    if (s == "N") return Color(0xFFFF9800);
    return Colors.grey;
  }

  String _statusText(String s) {
    if (s == "Y") return "Billed";
    if (s == "N") return "Pending";
    return s;
  }

  Widget _orderTile(Map<String, dynamic> o) {
    final ordNo = o["ord_no"]?.toString() ?? "-";
    final ordDate = o["ord_date"]?.toString() ?? "-";
    final trxTotal = o["trx_total"] ?? 0;
    final trxNet = o["trx_netamount"] ?? 0;
    final status = o["status_flag"]?.toString() ?? "-";
    final custName = (o["cust_name"] ?? "").toString().trim();

    return GestureDetector(
      onTap: () async {
        final deletedOrUpdated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => OrderDetailPage(ordNo: int.tryParse(ordNo) ?? 0),
          ),
        );

        if (deletedOrUpdated == true) {
          await _refresh();
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 7.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // top row
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Order #$ordNo",
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    _statusText(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 10.h),

            // customer name
            if (custName.isNotEmpty)
              Text(
                custName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF6C63FF),
                ),
              ),

            if (custName.isNotEmpty) SizedBox(height: 6.h),

            // date row
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14.sp,
                  color: Colors.black45,
                ),
                SizedBox(width: 6.w),
                Text(
                  ordDate,
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),

            SizedBox(height: 14.h),

            // amount row
            Row(
              children: [
                Expanded(
                  child: _modernStatPill(
                    label: "Total",
                    value: "₹${_formatMoney(trxTotal)}",
                    bg: const Color(0xFFF3F0FF),
                    fg: const Color(0xFF6C63FF),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _modernStatPill(
                    label: "Net",
                    value: "₹${_formatMoney(trxNet)}",
                    bg: const Color(0xFFEAF8EC),
                    fg: const Color(0xFF2E7D32),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  height: 42.w,
                  width: 42.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black45,
                    size: 24.sp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black54,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _filtersBar() {
    final fromText = _fromDate == null ? "From Date" : _fmt(_fromDate!);
    final toText = _toDate == null ? "To Date" : _fmt(_toDate!);

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Orders',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  label: "All",
                  selected: _status == "ALL",
                  onTap: () => _setStatus("ALL"),
                ),
                SizedBox(width: 10.w),
                _filterChip(
                  label: "Pending",
                  selected: _status == "N",
                  onTap: () => _setStatus("N"),
                ),
                SizedBox(width: 10.w),
                _filterChip(
                  label: "Billed",
                  selected: _status == "Y",
                  onTap: () => _setStatus("Y"),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickFromDate,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 12.h,
                      horizontal: 12.w,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _fromDate != null ? Color(0xFFEEEDFF) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            _fromDate != null
                                ? Color(0xFF6C63FF)
                                : Colors.black12,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16.w,
                          color:
                              _fromDate != null
                                  ? Color(0xFF6C63FF)
                                  : Colors.black54,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          fromText,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color:
                                _fromDate != null
                                    ? Color(0xFF6C63FF)
                                    : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: GestureDetector(
                  onTap: _pickToDate,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 12.h,
                      horizontal: 12.w,
                    ),
                    decoration: BoxDecoration(
                      color: _toDate != null ? Color(0xFFEEEDFF) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            _toDate != null
                                ? Color(0xFF6C63FF)
                                : Colors.black12,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16.w,
                          color:
                              _toDate != null
                                  ? Color(0xFF6C63FF)
                                  : Colors.black54,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          toText,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color:
                                _toDate != null
                                    ? Color(0xFF6C63FF)
                                    : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_fromDate != null || _toDate != null) ...[
                SizedBox(width: 10.w),
                GestureDetector(
                  onTap: _clearDates,
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.clear, size: 20.w, color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(375, 812),
      child: Scaffold(
        backgroundColor: Color(0xFFF8F9FE),
        appBar: AppBar(
          backgroundColor: Color(0xFFF8F9FE),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Order History",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: Icon(Icons.refresh, color: Color(0xFF6C63FF)),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: Color(0xFF6C63FF),
          child: Column(
            children: [
              _filtersBar(),
              _subtotalCard(),
              Expanded(
                child: _isInitialLoading
                    ? const ListLoading()
                    : Stack(
                          children: [
                            if (_orders.isEmpty)
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 80.w,
                                      color: Colors.black26,
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      "No matching orders",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16.sp,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      "Change the status or date filters to see results",
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.builder(
                                controller: _scrollController,
                                physics: AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.only(bottom: 20.h),
                                itemCount:
                                    _orders.length + (_isPageLoading ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _orders.length) {
                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 18.h,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          height: 24.w,
                                          width: 24.w,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF6C63FF),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return _orderTile(_orders[index]);
                                },
                              ),
                            if (!_hasMore && _orders.isNotEmpty)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 18.h),
                                  child: Center(
                                    child: Text(
                                      "No more orders",
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.sp,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
