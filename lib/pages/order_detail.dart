import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:ezbiz/Consts/consts.dart';

class OrderDetailPage extends StatefulWidget {
  final int ordNo;

  const OrderDetailPage({Key? key, required this.ordNo}) : super(key: key);

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _orderData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception("Auth token missing. Please login again.");
    }

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<void> _fetchOrderDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final headers = await _authHeaders();
      final uri = Uri.parse("$baseUrl/orders/${widget.ordNo}");

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _orderData = data;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _errorMessage = "Session expired. Please login again.";
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load order details";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    if (status.toUpperCase() == "BILLED" || status == "Y") return Color(0xFF4CAF50);
    if (status.toUpperCase() == "PENDING" || status == "N") return Color(0xFFFF9800);
    return Colors.grey;
  }

  String _statusText(String status) {
    if (status.toUpperCase() == "BILLED" || status == "Y") return "Billed";
    if (status.toUpperCase() == "PENDING" || status == "N") return "Pending";
    return status;
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: List.generate(5, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: 15.h),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                height: 100.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80.w,
              color: Colors.red.shade300,
            ),
            SizedBox(height: 16.h),
            Text(
              _errorMessage ?? "Something went wrong",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: _fetchOrderDetails,
              icon: Icon(Icons.refresh),
              label: Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 14.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final lineNo = item["line_no"]?.toString() ?? "-";
    final itemName = item["item_name"]?.toString() ?? "Unknown Item";
    final qty = item["qty"]?.toString() ?? "0";
    final price = item["price"]?.toString() ?? "0";
    final tax = item["tax"]?.toString() ?? "0";
    final discount = item["discount"]?.toString() ?? "0";
    final total = item["total"]?.toString() ?? "0";

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFEEEDFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  itemName,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Color(0xFFEEEDFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Item #$lineNo",
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _itemDetail("Qty", qty),
              ),
              Expanded(
                child: _itemDetail("Price", "₹$price"),
              ),
              Expanded(
                child: _itemDetail("Tax", "$tax%"),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _itemDetail("Discount", "$discount%"),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Color(0xFF6C63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total",
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                      Text(
                        "₹$total",
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> summary) {
    final totalQty = summary["total_qty"]?.toString() ?? "0";
    final subtotal = summary["subtotal"]?.toString() ?? "0";
    final tax = summary["tax"]?.toString() ?? "0";
    final discount = summary["discount"]?.toString() ?? "0";

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF5A52E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Order Summary",
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16.h),
          _summaryRow("Total Items", totalQty),
          _summaryRow("Subtotal", "₹$subtotal"),
          _summaryRow("Tax", "$tax%"),
          _summaryRow("Discount", "$discount%"),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
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
            "Order #${widget.ordNo}",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
            ),
          ),
          actions: [
            if (!_isLoading)
              IconButton(
                onPressed: _fetchOrderDetails,
                icon: Icon(Icons.refresh, color: Color(0xFF6C63FF)),
              ),
          ],
        ),
        body: _isLoading
            ? _buildShimmerLoading()
            : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _fetchOrderDetails,
                    color: Color(0xFF6C63FF),
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Order Header
                          _buildInfoCard(
                            title: "Order Information",
                            children: [
                              _buildInfoRow(
                                "Order Number",
                                _orderData!["order"]["ord_no"].toString(),
                                isBold: true,
                              ),
                              _buildInfoRow(
                                "Date",
                                _orderData!["order"]["ord_date"].toString(),
                              ),
                              _buildInfoRow(
                                "Time",
                                _orderData!["order"]["ord_time"].toString(),
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: 4.h),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Status",
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12.w,
                                        vertical: 6.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          _orderData!["order"]["status"].toString(),
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _statusText(
                                          _orderData!["order"]["status"].toString(),
                                        ),
                                        style: TextStyle(
                                          color: _statusColor(
                                            _orderData!["order"]["status"].toString(),
                                          ),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Customer Info
                          _buildInfoCard(
                            title: "Customer Details",
                            children: [
                              // _buildInfoRow(
                              //   "Name",
                              //   _orderData!["order"]["customer"]["name"].toString(),
                              //   isBold: true,
                              // ),
                              _buildInfoRow(
                                "Code",
                                _orderData!["order"]["customer"]["code"].toString(),
                              ),
                              // _buildInfoRow(
                              //   "Phone",
                              //   _orderData!["order"]["customer"]["phone"].toString(),
                              // ),
                              // _buildInfoRow(
                              //   "Address",
                              //   _orderData!["order"]["customer"]["address"].toString(),
                              // ),
                              // _buildInfoRow(
                              //   "Area",
                              //   _orderData!["order"]["customer"]["area"].toString(),
                              // ),
                            ],
                          ),

                          // Order Totals
                          _buildInfoCard(
                            title: "Order Totals",
                            children: [
                              _buildInfoRow(
                                "Total Amount",
                                "₹${_orderData!["order"]["totals"]["trx_total"]}",
                                isBold: true,
                              ),
                              _buildInfoRow(
                                "Net Amount",
                                "₹${_orderData!["order"]["totals"]["trx_netamount"]}",
                                isBold: true,
                              ),
                            ],
                          ),

                          // Items
                          Text(
                            "Order Items",
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          ...(_orderData!["items"] as List)
                              .map((item) => _buildItemCard(item))
                              .toList(),

                          SizedBox(height: 8.h),

                          // Summary
                          _buildSummaryCard(
                            _orderData!["computed_summary"],
                          ),

                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}