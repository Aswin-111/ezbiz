// lib/pages/user_details_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ezbiz/DetailWidgets/cart_item_card.dart';
import 'package:ezbiz/DetailWidgets/checkout_bar.dart';
import 'package:ezbiz/DetailWidgets/customer_info_card.dart';
import 'package:ezbiz/DetailWidgets/item_searchbar.dart';
import 'package:ezbiz/DetailWidgets/shop_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'package:ezbiz/Consts/consts.dart';
import 'package:ezbiz/pages/order_pdf.dart';
import 'package:shimmer/shimmer.dart';


class UserDetailsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String compCode;
  final String custType;

  const UserDetailsPage({
    super.key,
    required this.userData,
    required this.compCode,
    required this.custType,
  });

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
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


  @override
  void initState() {
    super.initState();
    _showShopDetails = true; 
    _fetchUserDetails();
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
        setState(() {
          _userDetails = jsonData is List
              ? List<Map<String, dynamic>>.from(jsonData)
              : List<Map<String, dynamic>>.from(jsonData['details'] ?? []);
          _filteredDetails = List.from(_userDetails);
          _isLoading = false;
        });
      } else {
        _showErrorSnackBar(
            "Failed to fetch details. Status: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorSnackBar("Error fetching data: $e");
    }
  }

  Future<void> _placeOrderAndGetPdf() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    final requestBody = {
      'comp_code': widget.compCode,
      'user_id': userId,
      'order_details': _addedItems,
    };

    try {
      final headers = await authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        body: jsonEncode(requestBody),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final pdfBytes = _parsePdfBytes(response);
        final file = await _savePdfToFile(pdfBytes);

        setState(() {
          _isLoading = false;
          _addedItems.clear();
        });

        _navigateToPdfPreview(file);
        _showSuccessSnackBar('Order submitted successfully!');
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar(
            'Failed to submit order. Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error submitting order: $e');
    }
  }

  // ==================== HELPER METHODS ====================

  Uint8List _parsePdfBytes(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final keys = decoded.keys.toList()
          ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
        final pdfBytes = Uint8List(keys.length);
        for (int i = 0; i < keys.length; i++) {
          pdfBytes[i] = (decoded[keys[i]] as num).toInt();
        }
        return pdfBytes;
      } else if (decoded is List) {
        return Uint8List.fromList(
          decoded.map<int>((e) => (e as num).toInt()).toList(),
        );
      }
    } catch (_) {}
    return response.bodyBytes;
  }

  Future<File> _savePdfToFile(Uint8List pdfBytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/order_bill.pdf');
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  void _navigateToPdfPreview(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(pdfFile: file),
      ),
    );
  }

  double _getItemRate(Map<String, dynamic> item) {
    final p1 = double.tryParse(item['item_price1']?.toString() ?? '0') ?? 0;
    final p2 = double.tryParse(item['item_price2']?.toString() ?? '0') ?? 0;

    if (widget.custType == 'W') {
      return p2 > 0 ? p2 : p1;
    }
    return p1;
  }

  double _calculateTotal() {
    return _addedItems.fold(0.0, (total, item) {
      final subtotal =
          double.tryParse(item['subtotal']?.toString() ?? '0') ?? 0;
      return total + subtotal;
    });
  }

  void _filterSearchResults(String query) {
    setState(() {
      _filteredDetails = query.isEmpty
          ? List.from(_userDetails)
          : _userDetails.where((item) {
              final name =
                  (item['item_name'] ?? '').toString().toLowerCase();
              return name.contains(query.toLowerCase());
            }).toList();
    });
  }

  void _addItemToOrder(
      Map<String, dynamic> oldItem, Map<String, dynamic> newItem) {
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

  void _recalculateFromRate(
      Map<String, TextEditingController> controllers) {
    final rate = double.tryParse(controllers['rate']!.text) ?? 0.0;
    final tax = double.tryParse(controllers['tax']!.text) ?? 0.0;
    final discount =
        double.tryParse(controllers['discount']!.text) ?? 0.0;
    final quantity = double.tryParse(controllers['qty']!.text) ?? 1.0;

    final netrate = rate + (rate * tax / 100);
    final subtotalTarget = rate - (rate * discount / 100);
    final subtotal =
        (subtotalTarget + (subtotalTarget * tax / 100)) * quantity;

    controllers['netrate']!.text = netrate.toStringAsFixed(2);
    controllers['subtotal']!.text = subtotal.toStringAsFixed(2);
  }

  void _recalculateFromNetRate(
      Map<String, TextEditingController> controllers) {
    final netrate = double.tryParse(controllers['netrate']!.text) ?? 0.0;
    final tax = double.tryParse(controllers['tax']!.text) ?? 0.0;
    final discount =
        double.tryParse(controllers['discount']!.text) ?? 0.0;
    final quantity = double.tryParse(controllers['qty']!.text) ?? 1.0;

    final rate = netrate / (1 + (tax / 100));
    final subtotalTarget = rate * (1 - (discount / 100));
    final subtotal =
        (subtotalTarget * (1 + (tax / 100))) * quantity;

    controllers['rate']!.text = rate.toStringAsFixed(2);
    controllers['subtotal']!.text = subtotal.toStringAsFixed(2);
  }

  Map<String, TextEditingController> _createControllers(
      Map<String, dynamic> item) {
    final rate = _getItemRate(item);
    final tax =
        double.tryParse(item['item_tax']?.toString() ?? '') ?? 0.0;
    final netrate = rate + (rate * tax / 100);

    return {
      'stock': TextEditingController(
          text: item['item_qty']?.toString() ?? ''),
      'mrp': TextEditingController(
          text: item['item_mrp']?.toString() ?? ''),
      'tax': TextEditingController(
          text: item['item_tax']?.toString() ?? ''),
      'rate':
          TextEditingController(text: rate.toStringAsFixed(2)),
      'netrate':
          TextEditingController(text: netrate.toStringAsFixed(2)),
      'qty': TextEditingController(
          text: item['qty']?.toString() ?? '1'),
      'free': TextEditingController(
          text: item['free']?.toString() ?? ''),
      'discount': TextEditingController(
        text: item['discount']?.toString() ??
            item['item_disc']?.toString() ??
            '0',
      ),
      'offer': TextEditingController(
          text: item['offer']?.toString() ?? ''),
      'subtotal': TextEditingController(
          text: item['subtotal']?.toString() ?? ''),
    };
  }

  Map<String, dynamic> _collectUpdatedItem(
    Map<String, dynamic> item,
    Map<String, TextEditingController> controllers,
  ) {
    final rate = double.tryParse(controllers['rate']!.text) ?? 0.0;
    final tax = double.tryParse(controllers['tax']!.text) ?? 0.0;
    final discount =
        double.tryParse(controllers['discount']!.text) ?? 0.0;
    final quantity =
        double.tryParse(controllers['qty']!.text) ?? 1.0;
    final netrate = rate + (rate * tax / 100);
    final subtotalTarget = rate - (rate * discount / 100);
    final subtotal =
        (subtotalTarget + (subtotalTarget * tax / 100)) * quantity;

    return {
      'item_code': item['item_code'],
      'item_name': item['item_name'],
      'item_uom': item['item_uom'],
      'hsn_code': item['hsn_code'],
      'item_qty': int.tryParse(controllers['stock']!.text) ?? 0,
      'item_price1': rate,
      'item_mrp':
          double.tryParse(controllers['mrp']!.text) ?? 0.0,
      'item_tax': tax,
      'item_disc': discount,
      'qty': int.tryParse(controllers['qty']!.text) ?? 0,
      'free': int.tryParse(controllers['free']!.text) ?? 0,
      'offer': controllers['offer']!.text,
      'netrate': netrate,
      'subtotal': double.parse(subtotal.toStringAsFixed(2)),
    };
  }

  // ==================== SNACKBAR METHODS ====================

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE57373),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    setState(() => _isLoading = false);
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
        widget.userData['cust_name'] ?? 'Customer Details',
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
                    horizontal: 12, vertical: 6),
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
        custName: widget.userData['cust_name'] ?? '',
        custAddress: widget.userData['cust_address'] ?? '',
        custPhone: widget.userData['cust_phone'] ?? '',
        custType: widget.custType,
      ),
      ItemSearchBar(
        controller: _searchController,
        onTap: () => setState(() => _showShopDetails = true),
        onChanged: _filterSearchResults,
        onClear: () {
          _searchController.clear();
          _filterSearchResults('');
        },
      ),
      const SizedBox(height: 12),
      Expanded(
        child: _showShopDetails
            ? _buildShopDetailsView()
            : _buildCartView(),
      ),
      if (!_showShopDetails && _addedItems.isNotEmpty)
        CheckoutBar(
          total: _calculateTotal(),
          onPressed: _placeOrderAndGetPdf,
        ),
    ],
  );
}


  Widget _buildShopDetailsView() {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () =>
                    setState(() => _showShopDetails = false),
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
            Icon(Icons.search_off,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No items found',
              style:
                  TextStyle(fontSize: 16, color: Colors.grey[600]),
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
        final stock = item['item_qty'] ?? 0;

        return ShopItemCard(
          item: item,
          rate: rate,
          stock: stock,
          uom: uom,
          //onAdd: () => _showItemDialog(item),
          onAdd: () {
  if (_isItemAlreadyAdded(item)) {
    _showSuccessSnackBar(
      "This product is already added. Go to cart and edit the quantity.",
    );
    setState(() => _showShopDetails = false); // ✅ jump to cart
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
            Icon(Icons.shopping_cart_outlined,
                size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the search bar to add items',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Your Cart',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
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
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 40),
        child: StatefulBuilder(
          builder: (context, setDialogState) => Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height * 0.75,
              maxWidth: 500,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 5),
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
                        icon: Icon(Icons.close,
                            color: Colors.grey[600], size: 24),
                        padding: const EdgeInsets.all(5),
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            Navigator.pop(dialogContext),
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
          child: _buildDialogField('Stock', controllers['stock']!, enabled: false),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDialogField('MRP', controllers['mrp']!, enabled: false),
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
              _recalculateFromNetRate(controllers);
              setDialogState(() {});
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDialogField('Free', controllers['free']!),
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
                  padding: const EdgeInsets.fromLTRB(
                      20, 16, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(
                          color: Colors.grey[200]!, width: 1),
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
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            backgroundColor: Colors.grey[100],
                          ),
                          onPressed: () =>
                              Navigator.pop(dialogContext),
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
                            backgroundColor:
                                const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (_formKey.currentState!
                                .validate()) {
                              final updatedItem =
                                  _collectUpdatedItem(
                                      item, controllers);
                              // _addItemToOrder(
                              //     item, updatedItem);
                              // Navigator.pop(dialogContext);
                              // _showSuccessSnackBar(
                              //     'Item added to cart!');
                              _addItemToOrder(item, updatedItem);
setState(() => _showShopDetails = false); // ✅ go to cart after add
Navigator.pop(dialogContext);
_showSuccessSnackBar('Item added to cart!');

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
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white, // keeps it clean on Material 3
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  backgroundColor: const Color(0xFF6C63FF), // match app theme
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

    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      maxLines: maxLines,
      keyboardType: isOffer
          ? TextInputType.multiline
          : const TextInputType.numberWithOptions(decimal: true),
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
          borderSide:
              const BorderSide(color: Color(0xFF6C63FF), width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
      onChanged: onChanged,
      validator: (value) {
        if (label.toLowerCase() == 'quantity' &&
            (value == null || value.isEmpty)) {
          return 'Required';
        }
        return null;
      },
    );
  }

  Future<void> _confirmDeleteItem(
      Map<String, dynamic> item) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Item'),
        content: Text('Remove ${item['item_name']} from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              _deleteItem(item);
              Navigator.pop(context);
            },
            child: const Text('Remove',style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
