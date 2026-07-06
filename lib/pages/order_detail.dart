import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:ezbiz/widgets/list_loading.dart';
import 'package:ezbiz/helper/helper.dart';
import 'package:ezbiz/Consts/consts.dart';
import 'package:ezbiz/pages/edit_order_page.dart';

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
  bool _isEditMode = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _editableItems = [];
  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  void _showTopSnack(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade400 : const Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 80, 16, 0),
        duration: const Duration(milliseconds: 1200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _saveOrderEdits() async {
    try {
      setState(() => _isSaving = true);

      final headers = await authHeaders();

      final customer = _orderData!["order"]["customer"];

      final payload = {
        "ord_date": _orderData!["order"]["ord_date"],
        "ord_time": _orderData!["order"]["ord_time"],
        "status_flag": _orderData!["order"]["status"] == "BILLED" ? "Y" : "N",
        "customer": {
          "code": customer["code"],
          "name": customer["name"],
          "phone": customer["phone"],
          "address": customer["address"],
          "area": customer["area"],
        },
        "items":
            _editableItems.map((item) {
              return {
                "item_code": item["item_code"],
                "item_name": item["item_name"],
                "qty": item["qty"],
                "mrp": item["mrp"],
                "price": item["price"],
                "tax": item["tax"],
                "discount": item["discount"],
                "cess": item["cess"] ?? 0,
              };
            }).toList(),
      };

      final response = await http.put(
        Uri.parse("$baseUrl/orders/${widget.ordNo}"),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() => _isEditMode = false);
        await _fetchOrderDetails();
        _showTopSnack("Order updated successfully");
      } else {
        _showTopSnack("Failed to update order");
      }
    } catch (e) {
      _showTopSnack("Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteOrder() async {
    try {
      final headers = await authHeaders();

      final response = await http.delete(
        Uri.parse("$baseUrl/orders/${widget.ordNo}"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, {
          "deleted": true,
          "message": "Order deleted successfully",
        });
      } else {
        print("error when deleting : ${response.body}");

        _showTopSnack("Failed to delete order");
      }
    } catch (e) {
      print("error when deleting : ${e}");
      _showTopSnack("Error: $e");
    }
  }

  Future<void> _confirmSaveEdits() async {
    if (_editableItems.isEmpty) {
      _showTopSnack("Add at least one item before saving", isError: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Save changes?"),
            content: const Text(
              "This will update the order and all its items.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Save"),
              ),
            ],
          ),
    );

    if (ok == true) {
      await _saveOrderEdits();
    }
  }

  Future<void> _confirmDeleteOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Delete order?"),
            content: const Text(
              "This will permanently remove the order and all items.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Delete"),
              ),
            ],
          ),
    );

    if (ok == true) {
      await _deleteOrder();
    }
  }

  void _addNewItem() {
    setState(() {
      _editableItems.add({
        "line_no": _editableItems.length + 1,
        "item_code": "",
        "item_name": "",
        "qty": 1,
        "mrp": 0,
        "price": 0,
        "tax": 0,
        "discount": 0,
        "cess": 0,
        "total": 0,
      });
    });
  }

  void _removeItemAt(int index) {
    setState(() {
      _editableItems.removeAt(index);
      for (int i = 0; i < _editableItems.length; i++) {
        _editableItems[i]["line_no"] = i + 1;
      }
    });
  }

  Future<void> _fetchOrderDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final headers = await authHeaders();
      final uri = Uri.parse("$baseUrl/orders/${widget.ordNo}");

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _orderData = data;
          _editableItems = List<Map<String, dynamic>>.from(
            (data["items"] as List).map((e) => Map<String, dynamic>.from(e)),
          );
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        clearAuthAndNavigateToLogin();
        return;
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
    if (status.toUpperCase() == "BILLED" || status == "Y")
      return Color(0xFF4CAF50);
    if (status.toUpperCase() == "PENDING" || status == "N")
      return Color(0xFFFF9800);
    return Colors.grey;
  }

  String _statusText(String status) {
    if (status.toUpperCase() == "BILLED" || status == "Y") return "Billed";
    if (status.toUpperCase() == "PENDING" || status == "N") return "Pending";
    return status;
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80.w, color: Colors.red.shade300),
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

              if (_isEditMode)
                IconButton(
                  onPressed: () {
                    final index = _editableItems.indexOf(item);
                    if (index != -1) {
                      _removeItemAt(index);
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEDFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Item #$lineNo",
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6C63FF),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(child: _itemDetail("Qty", qty)),
              Expanded(child: _itemDetail("Price", "₹$price")),
              Expanded(child: _itemDetail("Tax", "$tax%")),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(child: _itemDetail("Discount", "$discount%")),
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
                onPressed: () async {
                  if (_orderData == null) return;

                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => EditOrderPage(
                            ordNo: widget.ordNo,
                            orderData: _orderData!,
                          ),
                    ),
                  );

                  if (updated == true) {
                    _fetchOrderDetails();
                  }
                },
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF6C63FF)),
              ),
            if (!_isLoading)
              IconButton(
                onPressed: _confirmDeleteOrder,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            if (!_isLoading)
              IconButton(
                onPressed: _fetchOrderDetails,
                icon: const Icon(Icons.refresh, color: Color(0xFF6C63FF)),
              ),
          ],
        ),
        body: Stack(
          children: [
            _isLoading
                ? const ListLoading()
                : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
                  onRefresh: _fetchOrderDetails,
                  color: const Color(0xFF6C63FF),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                        _orderData!["order"]["status"]
                                            .toString(),
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _statusText(
                                        _orderData!["order"]["status"]
                                            .toString(),
                                      ),
                                      style: TextStyle(
                                        color: _statusColor(
                                          _orderData!["order"]["status"]
                                              .toString(),
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

                        _buildInfoCard(
                          title: "Customer Details",
                          children: [
                            _buildInfoRow(
                              "Name",
                              _orderData!["order"]["customer"]["name"]
                                      ?.toString() ??
                                  "-",
                              isBold: true,
                            ),
                            _buildInfoRow(
                              "Code",
                              _orderData!["order"]["customer"]["code"]
                                      ?.toString() ??
                                  "-",
                            ),
                            _buildInfoRow(
                              "Phone",
                              _orderData!["order"]["customer"]["phone"]
                                      ?.toString() ??
                                  "-",
                            ),
                            _buildInfoRow(
                              "Address",
                              _orderData!["order"]["customer"]["address"]
                                      ?.toString() ??
                                  "-",
                            ),
                            _buildInfoRow(
                              "Area",
                              _orderData!["order"]["customer"]["area"]
                                      ?.toString() ??
                                  "-",
                            ),
                          ],
                        ),

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

                        Text(
                          "Order Items",
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 12.h),

                        ..._editableItems
                            .map((item) => _buildItemCard(item))
                            .toList(),

                        if (_isEditMode) ...[
                          SizedBox(height: 8.h),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _addNewItem,
                              icon: const Icon(
                                Icons.add,
                                color: Color(0xFF6C63FF),
                              ),
                              label: const Text(
                                "Add New Item",
                                style: TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                side: const BorderSide(
                                  color: Color(0xFF6C63FF),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 8.h),
                        _buildSummaryCard(_orderData!["computed_summary"]),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),

            if (_isSaving)
              Container(
                color: Colors.white.withOpacity(0.75),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
