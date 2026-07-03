// lib/pages/user_details_page.dart
import 'dart:convert';

import 'package:ezbiz/DetailWidgets/cart_item_card.dart';
import 'package:ezbiz/DetailWidgets/checkout_bar.dart';
import 'package:ezbiz/DetailWidgets/customer_info_card.dart';
import 'package:ezbiz/DetailWidgets/item_searchbar.dart';
import 'package:ezbiz/DetailWidgets/shop_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ezbiz/Consts/consts.dart';

import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

class EditOrderPage extends StatefulWidget {
  final int ordNo;
  final Map<String, dynamic> orderData;

  const EditOrderPage({
    super.key,
    required this.ordNo,
    required this.orderData,
  });

  @override
  State<EditOrderPage> createState() => _EditOrderPageState();
}

class _EditOrderPageState extends State<EditOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _userDetails = [];
  List<Map<String, dynamic>> _filteredDetails = [];
  final List<Map<String, dynamic>> _addedItems = [];

  bool _isLoading = true;
  bool _showShopDetails = false;
  bool _isItemAlreadyAdded(Map<String, dynamic> item) {
    return _addedItems.any((e) => e['item_code'] == item['item_code']);
  }

  Future<void> _confirmSaveOrder() async {
    if (_addedItems.isEmpty) {
      _showErrorSnackBar('Add at least one item before saving');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Save changes?'),
            content: const Text(
              'This will update the order and all its items.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (ok == true) {
      await _updateOrder();
    }
  }

  Future<void> _updateOrder() async {
    setState(() => _isLoading = true);

    try {
      final headers = await authHeaders();

      final payload = {
        "ord_date": widget.orderData["order"]["ord_date"],
        "ord_time": widget.orderData["order"]["ord_time"],
        "status_flag":
            widget.orderData["order"]["status"] == "BILLED" ? "Y" : "N",
        "customer": {
          "code": _customer["code"],
          "name": _customer["name"],
          "phone": _customer["phone"],
          "address": _customer["address"],
          "area": _customer["area"],
        },
        "items":
            _addedItems.map((item) {
              return {
                "item_code": item["item_code"],
                "item_name": item["item_name"],
                "qty": item["qty"],
                "mrp": item["item_mrp"] ?? item["mrp"] ?? 0,
                "price":
                    item["item_price"] ??
                    item["item_price1"] ??
                    item["price"] ??
                    0,
                "tax": item["item_tax"] ?? item["tax"] ?? 0,
                "discount": item["item_disc"] ?? item["discount"] ?? 0,
                "cess": item["item_cess"] ?? item["cess"] ?? 0,
              };
            }).toList(),
      };

      final response = await http.put(
        Uri.parse('$baseUrl/orders/${widget.ordNo}'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Order updated successfully!');
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        print("Error from response ${response.body}");
        _showErrorSnackBar(
          'Failed to update order. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error updating order: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> get _customer {
    final raw = widget.orderData["order"]?["customer"];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  final NumberFormat _moneyFormat = NumberFormat('#,##0.##');

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();

    final text = value.toString().trim();
    final asInt = int.tryParse(text);
    if (asInt != null) return asInt;

    final asDouble = double.tryParse(text);
    if (asDouble != null) return asDouble.toInt();

    return fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? fallback;
  }

  String _formatMoney(num value) {
    return _moneyFormat.format(value);
  }

  bool _isZeroLike(String value) {
    final v = value.trim();
    return v == '0' || v == '0.0' || v == '0.00';
  }

  @override
  void initState() {
    super.initState();
    _showShopDetails = false;

    final items =
        (widget.orderData['items'] as List? ?? [])
            .map((e) => _mapOrderItemToEditable(Map<String, dynamic>.from(e)))
            .toList();

    _addedItems.addAll(items.cast<Map<String, dynamic>>());

    _fetchUserDetails();
    debugPrint("EDIT ORDER DATA: ${jsonEncode(widget.orderData)}");
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  Future<Map<String, String>> authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    return {
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  // ==================== API CALLS ====================

  Future<void> _fetchUserDetails() async {
    try {
      final headers = await authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/shopdetails'),
        headers: headers,
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print("Fetch user details : $jsonData");

        final rawList =
            jsonData is List
                ? List<Map<String, dynamic>>.from(jsonData)
                : List<Map<String, dynamic>>.from(jsonData['details'] ?? []);

        final normalized =
            rawList
                .map(
                  (item) => {
                    ...item,
                    'item_qty': _asInt(item['item_qty']),
                    'item_price1': _asDouble(item['item_price1']),
                    'item_price2': _asDouble(item['item_price2']),
                    'item_mrp': _asDouble(item['item_mrp']),
                    'item_tax': _asDouble(item['item_tax']),
                    'item_disc': _asDouble(item['item_disc']),
                  },
                )
                .toList();

        setState(() {
          _userDetails = normalized;
          _filteredDetails = List.from(normalized);
          _isLoading = false;
        });
      } else {
        _showErrorSnackBar(
          "Failed to fetch details. Status: ${response.statusCode}",
        );
      }
    } catch (e) {
      _showErrorSnackBar("Error fetching data: $e");
    }
  }

  // ==================== HELPER METHODS ====================

  double _getItemRate(Map<String, dynamic> item) {
    return _asDouble(item['item_price1']);
  }

  double _calculateTotal() {
    return _addedItems.fold(0.0, (total, item) {
      return total + _asDouble(item['subtotal']);
    });
  }

  void _filterSearchResults(String query) {
    setState(() {
      _filteredDetails =
          query.isEmpty
              ? List.from(_userDetails)
              : _userDetails.where((item) {
                final name = (item['item_name'] ?? '').toString().toLowerCase();
                return name.contains(query.toLowerCase());
              }).toList();
    });
  }

  void _addItemToOrder(
    Map<String, dynamic> oldItem,
    Map<String, dynamic> newItem,
  ) {
    setState(() {
      final index = _addedItems.indexWhere(
        (element) => element['item_code'] == oldItem['item_code'],
      );
      if (index >= 0) {
        _addedItems[index] = newItem;
      } else {
        _addedItems.add(newItem);
      }
    });
  }

  void _deleteItem(Map<String, dynamic> item) {
    setState(() {
      _addedItems.removeWhere(
        (element) => element['item_code'] == item['item_code'],
      );
    });
    _showSuccessSnackBar('Item removed from cart');
  }

  // ========== CALCULATION METHODS (UNCHANGED) ==========

  void _recalculateFromRate(Map<String, TextEditingController> controllers) {
    final rate = double.tryParse(controllers['rate']!.text) ?? 0.0;
    final tax = double.tryParse(controllers['tax']!.text) ?? 0.0;
    final discount = double.tryParse(controllers['discount']!.text) ?? 0.0;
    final quantity = double.tryParse(controllers['qty']!.text) ?? 1.0;

    final netrate = rate + (rate * tax / 100);
    final subtotalTarget = rate - (rate * discount / 100);
    final subtotal = (subtotalTarget + (subtotalTarget * tax / 100)) * quantity;

    controllers['netrate']!.text = netrate.toStringAsFixed(2);
    controllers['subtotal']!.text = subtotal.toStringAsFixed(2);
  }

  void _recalculateFromNetRate(Map<String, TextEditingController> controllers) {
    final netrate = double.tryParse(controllers['netrate']!.text) ?? 0.0;
    final tax = double.tryParse(controllers['tax']!.text) ?? 0.0;
    final discount = double.tryParse(controllers['discount']!.text) ?? 0.0;
    final quantity = double.tryParse(controllers['qty']!.text) ?? 1.0;

    final rate = netrate / (1 + (tax / 100));
    final subtotalTarget = rate * (1 - (discount / 100));
    final subtotal = (subtotalTarget * (1 + (tax / 100))) * quantity;

    controllers['rate']!.text = rate.toStringAsFixed(2);
    controllers['subtotal']!.text = subtotal.toStringAsFixed(2);
  }

  Map<String, TextEditingController> _createControllers(
    Map<String, dynamic> item,
  ) {
    final rate = _getItemRate(item);
    final tax = _asDouble(item['item_tax']);
    final netrate = rate + (rate * tax / 100);

    return {
      'stock': TextEditingController(text: _asInt(item['item_qty']).toString()),
      'mrp': TextEditingController(
        text: _asDouble(item['item_mrp']).toStringAsFixed(2),
      ),
      'tax': TextEditingController(
        text: _asDouble(item['item_tax']).toStringAsFixed(2),
      ),
      'rate': TextEditingController(text: rate.toStringAsFixed(2)),
      'netrate': TextEditingController(text: netrate.toStringAsFixed(2)),
      'qty': TextEditingController(
        text: item['qty'] != null ? _asDouble(item['qty']).toString() : '1',
      ),
      'free': TextEditingController(
        text: item['free'] != null ? _asDouble(item['free']).toString() : '',
      ),
      'discount': TextEditingController(
        text: _asDouble(
          item['discount'] ?? item['item_disc'],
        ).toStringAsFixed(2),
      ),
      'offer': TextEditingController(text: item['offer']?.toString() ?? ''),
      'subtotal': TextEditingController(
        text:
            item['subtotal'] != null
                ? _asDouble(item['subtotal']).toStringAsFixed(2)
                : '',
      ),
    };
  }

  Map<String, dynamic> _mapOrderItemToEditable(Map<String, dynamic> item) {
    final qty = (item['qty'] as num?)?.toDouble() ?? 1.0;
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final tax = (item['tax'] as num?)?.toDouble() ?? 0.0;
    final discount = (item['discount'] as num?)?.toDouble() ?? 0.0;
    final mrp = (item['mrp'] as num?)?.toDouble() ?? 0.0;

    final netrate = price + (price * tax / 100);
    final subtotalTarget = price - (price * discount / 100);
    final subtotal = (subtotalTarget + (subtotalTarget * tax / 100)) * qty;

    return {
      'line_no': item['line_no'],
      'item_code': item['item_code'],
      'item_name': item['item_name'],
      'item_uom': item['item_uom'] ?? '',
      'hsn_code': item['hsn_code'] ?? '',
      'item_qty': qty,
      'item_price1': price,
      'item_mrp': mrp,
      'item_tax': tax,
      'item_disc': discount,
      'qty': qty,
      'free': 0,
      'offer': '',
      'netrate': netrate,
      'subtotal': double.parse(subtotal.toStringAsFixed(2)),
      'price': price,
      'tax': tax,
      'discount': discount,
      'mrp': mrp,
      'cess': item['cess'] ?? 0,
    };
  }

  Map<String, dynamic> _collectUpdatedItem(
    Map<String, dynamic> item,
    Map<String, TextEditingController> controllers,
  ) {
    final rate = double.tryParse(controllers['rate']!.text) ?? 0.0;
    final tax = double.tryParse(controllers['tax']!.text) ?? 0.0;
    final discount = double.tryParse(controllers['discount']!.text) ?? 0.0;
    final quantity = double.tryParse(controllers['qty']!.text) ?? 1.0;
    final netrate = rate + (rate * tax / 100);
    final subtotalTarget = rate - (rate * discount / 100);
    final subtotal = (subtotalTarget + (subtotalTarget * tax / 100)) * quantity;

    return {
      'item_code': item['item_code'],
      'item_name': item['item_name'],
      'item_uom': item['item_uom'],
      'hsn_code': item['hsn_code'],
      'item_qty': _asInt(controllers['stock']!.text),
      'item_price1': rate,
      'item_mrp': _asDouble(controllers['mrp']!.text),
      'item_tax': tax,
      'item_disc': discount,
      'qty': _asDouble(controllers['qty']!.text, fallback: 1.0),
      'free': _asDouble(controllers['free']!.text),
      'offer': controllers['offer']!.text,
      'netrate': netrate,
      'subtotal': double.parse(subtotal.toStringAsFixed(2)),
    };
  }

  // ==================== SNACKBAR METHODS ====================

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,

        // 🔥 THIS FIXES THE OVERLAP
        margin: const EdgeInsets.fromLTRB(16, 100, 16, 0),

        duration: const Duration(milliseconds: 900),

        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFE57373),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 100, 16, 0),
        duration: const Duration(milliseconds: 1200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
  // ==================== UI BUILDERS ====================

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      // child: Scaffold(
      //   backgroundColor: const Color(0xFFF8F9FE),
      //   appBar: _buildAppBar(),
      //   body: _buildBody(),
      // ),
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FE),
          appBar: _buildAppBar(),
          body: _buildBody(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        // onPressed: () => Navigator.pop(context),
        onPressed: () async {
          final canPop = await _onWillPop();
          if (canPop && mounted) Navigator.pop(context);
        },
      ),
      title: Text(
        _customer['name']?.toString().isNotEmpty == true
            ? _customer['name'].toString()
            : 'Edit Order',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (_addedItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_addedItems.length} items',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
      children: [
        // Customer info card skeleton
        Padding(
          padding: const EdgeInsets.all(16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),

        // Search bar skeleton
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // List skeleton (items)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        // Left icon block
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Text lines
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 160,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 200,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 120,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8),
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
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildShimmerLoading();
    }

    return Column(
      children: [
        CustomerInfoCard(
          custName: (_customer['name'] ?? '').toString(),
          custAddress: (_customer['address'] ?? '').toString(),
          custPhone: (_customer['phone'] ?? '').toString(),
          custType: (_customer['type'] ?? '').toString(),
        ),

        if (_showShopDetails) ...[
          ItemSearchBar(
            controller: _searchController,
            onTap: () {},
            onChanged: _filterSearchResults,
            onClear: () {
              _searchController.clear();
              _filterSearchResults('');
            },
          ),
          const SizedBox(height: 12),
        ],

        Expanded(
          child: _showShopDetails ? _buildShopDetailsView() : _buildCartView(),
        ),

        if (!_showShopDetails && _addedItems.isNotEmpty)
          CheckoutBar(
            total: _calculateTotal(),
            title: 'Save Order',
            onPressed: _confirmSaveOrder,
          ),
      ],
    );
  }

  Widget _buildShopDetailsView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Add Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _showShopDetails = false),
                child: const Text('Back to Cart'),
              ),
            ],
          ),
        ),
        Expanded(child: _buildItemList()),
      ],
    );
  }

  Widget _buildItemList() {
    if (_filteredDetails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No items found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredDetails.length,
      itemBuilder: (context, index) {
        final item = _filteredDetails[index];
        final rate = _getItemRate(item);
        final uom = (item['item_uom'] ?? '').toString();

        // ✅ force numeric type safely
        final int stock = _asInt(item['item_qty']);

        return ShopItemCard(
          item: item,
          rate: rate,
          stock: stock,
          uom: uom,
          onAdd: () {
            if (_isItemAlreadyAdded(item)) {
              _showSuccessSnackBar(
                "This product is already added. Go to cart and edit the quantity.",
              );
              setState(() => _showShopDetails = false);
              return;
            }
            _showItemDialog(item);
          },
        );
      },
    );
  }

  Widget _buildCartView() {
    if (_addedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No items in this order',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap below to add items',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showShopDetails = true),
              icon: const Icon(Icons.add),
              label: const Text('Add Items'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Your Cart',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _showShopDetails = true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Items'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _addedItems.length,
            itemBuilder: (context, index) {
              final item = _addedItems[index];
              return CartItemCard(
                item: item,
                onEdit: () => _showItemDialog(item),
                onDelete: () => _confirmDeleteItem(item),
              );
            },
          ),
        ),
      ],
    );
  }
  // ==================== DIALOG METHODS (UNCHANGED INSIDE) ====================

  void _showItemDialog(Map<String, dynamic> item) {
    final controllers = _createControllers(item);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 40,
            ),
            child: StatefulBuilder(
              builder:
                  (context, setDialogState) => Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.75,
                      maxWidth: 500,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 5,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8F9FE),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item['item_name'] ?? "Edit Item",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Colors.grey[600],
                                  size: 24,
                                ),
                                padding: const EdgeInsets.all(5),
                                constraints: const BoxConstraints(),
                                onPressed: () => Navigator.pop(dialogContext),
                              ),
                            ],
                          ),
                        ),

                        // Content
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Stock + MRP (2 in row)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDialogField(
                                          'Stock',
                                          controllers['stock']!,
                                          enabled: false,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDialogField(
                                          'MRP',
                                          controllers['mrp']!,
                                          enabled: false,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Tax + Discount + Quantity (3 in row)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDialogField(
                                          'Tax',
                                          controllers['tax']!,
                                          onChanged: (_) {
                                            _recalculateFromRate(controllers);
                                            setDialogState(() {});
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDialogField(
                                          'Discount',
                                          controllers['discount']!,
                                          onChanged: (_) {
                                            _recalculateFromRate(controllers);
                                            setDialogState(() {});
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDialogField(
                                          'Quantity',
                                          controllers['qty']!,
                                          autofocus: true,
                                          onChanged: (_) {
                                            _recalculateFromRate(controllers);
                                            setDialogState(() {});
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Rate + Net Rate + Free (3 in row)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDialogField(
                                          'Rate',
                                          controllers['rate']!,
                                          onChanged: (_) {
                                            _recalculateFromRate(controllers);
                                            setDialogState(() {});
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDialogField(
                                          'Net Rate',
                                          controllers['netrate']!,
                                          onChanged: (_) {
                                            _recalculateFromNetRate(
                                              controllers,
                                            );
                                            setDialogState(() {});
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDialogField(
                                          'Free',
                                          controllers['free']!,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: _buildDialogField(
                                          'Offer Remark',
                                          controllers['offer']!,
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 1,
                                        child: _buildDialogField(
                                          'Subtotal',
                                          controllers['subtotal']!,
                                          enabled: false,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Actions
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: Colors.grey[100],
                                  ),
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6C63FF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      final updatedItem = _collectUpdatedItem(
                                        item,
                                        controllers,
                                      );
                                      // _addItemToOrder(
                                      //     item, updatedItem);
                                      // Navigator.pop(dialogContext);
                                      // _showSuccessSnackBar(
                                      //     'Item added to cart!');
                                      _addItemToOrder(item, updatedItem);
                                      setState(
                                        () => _showShopDetails = false,
                                      ); // ✅ go to cart after add
                                      Navigator.pop(dialogContext);
                                      _showSuccessSnackBar(
                                        'Item added to cart!',
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Add',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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
          ),
    );
  }

  Future<bool> _onWillPop() async {
    final hasUnsavedData =
        _addedItems.isNotEmpty || _searchController.text.trim().isNotEmpty;

    if (!hasUnsavedData) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white, // keeps it clean on Material 3
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            title: const Text(
              "Discard changes?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            content: Text(
              "You have items in the cart. If you go back now, your data will be lost.",
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        "Stay",
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF6C63FF,
                        ), // match app theme
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        "Go Back",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );

    return shouldLeave ?? false;
  }

  Widget _buildDialogField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    bool autofocus = false,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    final isOffer = label.toLowerCase() == 'offer remark';
    final isNumericField = !isOffer;

    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      maxLines: maxLines,
      keyboardType:
          isOffer
              ? TextInputType.multiline
              : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters:
          isNumericField
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : null,
      style: TextStyle(
        fontSize: 15,
        color: enabled ? Colors.black87 : Colors.grey[600],
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: enabled ? Colors.grey[50] : Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      onTap: () {
        if (enabled && isNumericField && _isZeroLike(controller.text)) {
          controller.clear();
        }
      },
      onChanged: onChanged,
      validator: (value) {
        if (label.toLowerCase() == 'quantity' &&
            (value == null || value.trim().isEmpty)) {
          return 'Required';
        }
        return null;
      },
    );
  }

  Future<void> _confirmDeleteItem(Map<String, dynamic> item) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Remove Item'),
            content: Text('Remove ${item['item_name']} from cart?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _deleteItem(item);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}
