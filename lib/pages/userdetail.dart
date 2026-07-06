// lib/pages/user_details_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ezbiz/DetailWidgets/cart_item_card.dart';
import 'package:ezbiz/DetailWidgets/checkout_bar.dart';
import 'package:ezbiz/DetailWidgets/customer_info_card.dart';
import 'package:ezbiz/DetailWidgets/item_searchbar.dart';
import 'package:ezbiz/DetailWidgets/shop_item.dart';
import 'package:ezbiz/helper/helper.dart';
import 'package:ezbiz/helper/page_limit.dart';
import 'package:ezbiz/models/shop_details_response.dart';
import 'package:ezbiz/widgets/list_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ezbiz/Consts/consts.dart';
import 'package:ezbiz/pages/order_pdf.dart';
import 'package:intl/intl.dart';

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
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _userDetails = [];
  List<Map<String, dynamic>> _filteredDetails = [];
  final List<Map<String, dynamic>> _addedItems = [];

  // Pagination state — _limit is computed from screen height after first frame
  int _page = 1;
  int _limit = 12; // fallback; overridden in initState post-frame callback
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool _isFetchingItems = true;
  bool _isGeneratingBill = false;
  bool _showShopDetails = false;
  bool _isItemAlreadyAdded(Map<String, dynamic> item) {
    return _addedItems.any((e) => e['item_code'] == item['item_code']);
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
    _showShopDetails = true;
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchNextPage();
      }
    });
    // Compute responsive limit after the first frame so MediaQuery is available,
    // then kick off the initial fetch with the correct page size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Card ~92 px tall + 12 px bottom margin = 104 px per row.
      // Overhead: AppBar(56) + CustomerInfoCard(~100) + SearchBar(~60)
      //           + "Available Items" header row(~50) + padding(~20) ≈ 286 px.
      _limit = computePageLimit(
        context,
        cardHeight: 104,
        overhead: 286,
        min: 8,
        max: 25,
      );
      _fetchPage(page: 1);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
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

  Future<void> _fetchPage({required int page}) async {
    if (!mounted) return;
    if (page == 1) {
      setState(() => _isFetchingItems = true);
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final headers = await authHeaders();

      final body = <String, dynamic>{
        'comp_code': widget.compCode,
        'page': page,
        'limit': _limit,
      };
      final searchTerm = _searchController.text.trim();
      if (searchTerm.isNotEmpty) body['search'] = searchTerm;

      final response = await http.post(
        Uri.parse('$baseUrl/shopdetails'),
        headers: headers,
        body: jsonEncode(body),
      );

      debugPrint('SHOP DETAILS STATUS: ${response.statusCode}');

      if (response.statusCode == 401) {
        clearAuthAndNavigateToLogin();
        return;
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch items. Status: ${response.statusCode}',
        );
      }

      final parsed = ShopDetailsResponse.fromJson(jsonDecode(response.body));

      final normalized = parsed.data.map<Map<String, dynamic>>((item) {
        return {
          ...item,
          'item_code': (item['item_code'] ?? '').toString(),
          'item_name': (item['item_name'] ?? '').toString(),
          'item_uom': (item['item_uom'] ?? '').toString(),
          'item_qty': _asInt(item['item_qty']),
          'item_price1': _asDouble(item['item_price1']),
          'item_price2': _asDouble(item['item_price2']),
          'item_price3': _asDouble(item['item_price3']),
          'item_price4': _asDouble(item['item_price4']),
          'item_price5': _asDouble(item['item_price5']),
          'item_mrp': _asDouble(item['item_mrp']),
          'item_tax': _asDouble(item['item_tax']),
          'item_disc': _asDouble(item['item_disc']),
          'item_cess': _asDouble(item['item_cess']),
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _page = page;
        _hasMore = page < parsed.totalPages;

        if (page == 1) {
          _userDetails = normalized;
        } else {
          _userDetails = [..._userDetails, ...normalized];
        }
        _filteredDetails = List<Map<String, dynamic>>.from(_userDetails);
      });

      if (page == 1 && normalized.isEmpty) {
        _showErrorSnackBar('No items found.');
      }
    } catch (error, stackTrace) {
      debugPrint('SHOP DETAILS ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showErrorSnackBar('Error fetching items: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingItems = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _fetchNextPage() async {
    if (!_hasMore || _isLoadingMore || _isFetchingItems) return;
    await _fetchPage(page: _page + 1);
  }

 Future<void> _placeOrderAndGetPdf() async {
  if (_addedItems.isEmpty) {
    _showErrorSnackBar('Add at least one item');
    return;
  }

  setState(() {
    _isGeneratingBill = true;
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    final requestBody = {
      'comp_code': widget.compCode,
      'user_id': userId,
      'customer': {
        'code': (widget.userData['cust_code'] ?? '').toString(),
        'name': (widget.userData['cust_name'] ?? '').toString(),
        'phone': (widget.userData['cust_phone'] ?? '').toString(),
        'address': (widget.userData['cust_address'] ?? '').toString(),
        'area': (widget.userData['cust_area'] ?? '').toString(),
        'type': (widget.userData['cust_type'] ?? widget.custType).toString(),
      },
      'order_details': _addedItems,
    };

    final headers = await authHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      body: jsonEncode(requestBody),
      headers: headers,
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
        'Order failed. Status: ${response.statusCode}, '
        'Response: ${response.body}',
      );
    }

    final pdfBytes = _parsePdfBytes(response);
    final file = await _savePdfToFile(pdfBytes);

    if (!mounted) return;

    setState(() {
      _addedItems.clear();
    });

    _showSuccessSnackBar('Order submitted successfully!');
    _navigateToPdfPreview(file);
  } catch (error) {
    if (mounted) {
      _showErrorSnackBar('Error submitting order: $error');
    }
  } finally {
    if (mounted) {
      setState(() {
        _isGeneratingBill = false;
      });
    }
  }
}
  // ==================== HELPER METHODS ====================

  Uint8List _parsePdfBytes(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final keys =
            decoded.keys.toList()
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
      MaterialPageRoute(builder: (context) => PdfPreviewScreen(pdfFile: file)),
    );
  }

  double _netRateToRate(double netRate, double taxPercent) {
    if (taxPercent <= 0) return netRate;
    return netRate / (1 + (taxPercent / 100));
  }

  double _getItemNetRate(Map<String, dynamic> item) {
    final p1 = _asDouble(item['item_price1']);
    final p2 = _asDouble(item['item_price2']);

    if (widget.custType == 'W') {
      return p2 > 0 ? p2 : p1;
    }
    return p1;
  }

  double _calculateTotal() {
    return _addedItems.fold(0.0, (total, item) {
      return total + _asDouble(item['subtotal']);
    });
  }

  void _filterSearchResults(String query) {
    // Immediate client-side filter over already-loaded items for instant feedback.
    setState(() {
      if (query.isEmpty) {
        _filteredDetails = List.from(_userDetails);
      } else {
        final q = query.toLowerCase().trim();
        _filteredDetails = _userDetails.where((item) {
          final code = (item['item_code'] ?? '').toString().toLowerCase();
          final name = (item['item_name'] ?? '').toString().toLowerCase();
          return code.contains(q) || name.contains(q);
        }).toList();
      }
    });

    // Debounced server-side search so we fetch all pages for this query.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _page = 1;
        _hasMore = true;
        _userDetails = [];
        _filteredDetails = [];
      });
      _fetchPage(page: 1);
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
    final tax = _asDouble(item['item_tax']);
    final netrate = _getItemNetRate(item);
    final rate = _netRateToRate(netrate, tax);

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
          body: Stack(
            children: [
              _buildBody(),
              if (_isGeneratingBill) _buildGeneratingBillLoader(),
            ],
          ),
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

  Widget _buildBody() {
    // CustomerInfoCard and ItemSearchBar are always in the tree so the
    // keyboard cursor is never dropped when a new page-1 fetch begins.
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
            _searchDebounce?.cancel();
            setState(() {
              _page = 1;
              _hasMore = true;
              _userDetails = [];
              _filteredDetails = [];
            });
            _fetchPage(page: 1);
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _showShopDetails ? _buildShopDetailsView() : _buildCartView(),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                onPressed: () => setState(() => _showShopDetails = false),
              ),
            ],
          ),
        ),
        Expanded(child: _buildItemList()),
      ],
    );
  }

  Widget _buildItemList() {
    // Show spinner in the list area only — search bar stays mounted above.
    if (_isFetchingItems) return const ListLoading();

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

    // Extra slot at the end for the next-page spinner.
    final itemCount = _filteredDetails.length + (_isLoadingMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == _filteredDetails.length) {
          return const PageLoadingIndicator();
        }

        final item = _filteredDetails[index];
        final rate = _getItemNetRate(item);
        final uom = (item['item_uom'] ?? '').toString();
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
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

Widget _buildGeneratingBillLoader() {
  return Container(
    color: Colors.white.withOpacity(0.95),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),

          const CircularProgressIndicator(
            color: Color(0xFF6C63FF),
            strokeWidth: 3,
          ),

          const SizedBox(height: 24),

          const Text(
            "Generating Bill...",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6C63FF),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            "Please wait while we prepare your invoice",
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    ),
  );
}
