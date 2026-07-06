import 'dart:async';
import 'dart:convert';

import 'package:ezbiz/Consts/consts.dart';
import 'package:ezbiz/DetailWidgets/cart_item_card.dart';
import 'package:ezbiz/DetailWidgets/shop_item.dart';
import 'package:ezbiz/helper/helper.dart';
import 'package:ezbiz/helper/responsive_page_size_mixin.dart';
import 'package:ezbiz/models/shop_details_response.dart';
import 'package:ezbiz/widgets/list_loading.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StockPage extends StatefulWidget {
  final String compCode;
  final String custType; // keep if you want to reuse same pricing logic (R/W)

  const StockPage({
    Key? key,
    required this.compCode,
    required this.custType,
  }) : super(key: key);

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage>
    with WidgetsBindingObserver, ResponsivePageSizeMixin<StockPage> {
  @override
  double get pageCardHeight => 104;
  @override
  double get pageOverhead => 216;

  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final List<Map<String, dynamic>> _addedItems = [];

  // Pagination state — _limit is computed from screen height after first frame
  int _page = 1;
  int _limit = 12; // fallback; overridden in initState post-frame callback
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool _isLoading = true;
  bool _showShopDetails = true; // Stock page default shows shop items

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
      // Card ~92 px tall + 12 px bottom margin = 104 px per row.
      // Overhead: AppBar(56) + SearchBar(~60) + TotalBar(~60) + padding(~40) ≈ 216 px.
      _limit = computeInitialLimit();
      attachResponsivePageSize();
      _fetchPage(page: 1);
    });
  }

  @override
  void onPageLimitChanged(int newLimit) {
    if (!mounted) return;
    setState(() => _limit = newLimit);
    _fetchPage(page: 1);
  }

  @override
  void dispose() {
    detachResponsivePageSize();
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ---------------- API ----------------

  Future<void> _fetchStocks() async => _fetchPage(page: 1);

  Future<void> _fetchPage({required int page}) async {
    if (!mounted) return;
    if (page == 1) {
      setState(() => _isLoading = true);
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

      if (response.statusCode == 401) {
        clearAuthAndNavigateToLogin();
        return;
      }

      if (response.statusCode != 200) {
        _showErrorSnackBar(
          "Failed to load stock. Status: ${response.statusCode}",
        );
        return;
      }

      final parsed = ShopDetailsResponse.fromJson(json.decode(response.body));

      if (!mounted) return;

      setState(() {
        _page = page;
        _hasMore = page < parsed.totalPages;
        if (page == 1) {
          _items = parsed.data;
        } else {
          _items = [..._items, ...parsed.data];
        }
        _filteredItems = List<Map<String, dynamic>>.from(_items);
      });
    } catch (e) {
      if (mounted) _showErrorSnackBar("Error fetching stock: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _fetchNextPage() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    await _fetchPage(page: _page + 1);
  }

  // ---------------- Helpers ----------------

  void _filterSearchResults(String query) {
    setState(() {}); // reflect suffix icon change immediately
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _fetchPage(page: 1);
    });
  }

  double _getItemRate(Map<String, dynamic> item) {
    final p1 = double.tryParse(item['item_price1']?.toString() ?? '0') ?? 0;
    final p2 = double.tryParse(item['item_price2']?.toString() ?? '0') ?? 0;

    if (widget.custType == 'W') {
      return p2 > 0 ? p2 : p1;
    }
    return p1;
  }

  double _calculateSubtotal() {
    return _addedItems.fold(0.0, (total, item) {
      final subtotal = double.tryParse(item['subtotal']?.toString() ?? '0') ?? 0;
      return total + subtotal;
    });
  }

  void _addItemToOrder(Map<String, dynamic> oldItem, Map<String, dynamic> newItem) {
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
    _showSuccessSnackBar('Item removed');
  }

  // ---------------- Snackbar ----------------

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE57373),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ---------------- UI ----------------


  Widget _subtotalBar() {
    final subtotal = _calculateSubtotal();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Subtotal: ₹${subtotal.toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: TextButton(
              onPressed: () => setState(() => _showShopDetails = !_showShopDetails),
              child: Text(_showShopDetails ? "View Cart" : "View Stock"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: _filterSearchResults,
        decoration: InputDecoration(
          hintText: "Search items...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchDebounce?.cancel();
                    _searchController.clear();
                    setState(() {});
                    _fetchPage(page: 1);
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
        ),
      ),
    );
  }

  Widget _buildItemList() {
    if (_filteredItems.isEmpty) {
      return Center(
        child: Text(
          'No items found',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    final itemCount = _filteredItems.length + (_isLoadingMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= _filteredItems.length) {
          return const PageLoadingIndicator();
        }
        final item = _filteredItems[index];
        final rate = _getItemRate(item);
        final uom = (item['item_uom'] ?? '').toString();
        final stock = item['item_qty'] ?? 0;

        return ShopItemCard(
          item: item,
          rate: rate,
          stock: stock,
          uom: uom,
          onAdd: () {},
          showAddButton: false,
        );
      },
    );
  }

  Widget _buildCartView() {
    if (_addedItems.isEmpty) {
      return Center(
        child: Text(
          'Cart is empty',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
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
    );
  }

  // ---------------- Dialog (copied logic style from your UserDetailsPage) ----------------

  Map<String, TextEditingController> _createControllers(Map<String, dynamic> item) {
    final rate = _getItemRate(item);
    final tax = double.tryParse(item['item_tax']?.toString() ?? '') ?? 0.0;
    final netrate = rate + (rate * tax / 100);

    return {
      'stock': TextEditingController(text: item['item_qty']?.toString() ?? ''),
      'mrp': TextEditingController(text: item['item_mrp']?.toString() ?? ''),
      'tax': TextEditingController(text: item['item_tax']?.toString() ?? ''),
      'rate': TextEditingController(text: rate.toStringAsFixed(2)),
      'netrate': TextEditingController(text: netrate.toStringAsFixed(2)),
      'qty': TextEditingController(text: item['qty']?.toString() ?? '1'),
      'free': TextEditingController(text: item['free']?.toString() ?? '0'),
      'discount': TextEditingController(
        text: item['discount']?.toString() ?? item['item_disc']?.toString() ?? '0',
      ),
      'offer': TextEditingController(text: item['offer']?.toString() ?? ''),
      'subtotal': TextEditingController(text: item['subtotal']?.toString() ?? ''),
    };
  }

  void _recalculateFromRate(Map<String, TextEditingController> c) {
    final rate = double.tryParse(c['rate']!.text) ?? 0.0;
    final tax = double.tryParse(c['tax']!.text) ?? 0.0;
    final discount = double.tryParse(c['discount']!.text) ?? 0.0;
    final qty = double.tryParse(c['qty']!.text) ?? 1.0;

    final netrate = rate + (rate * tax / 100);
    final subtotalTarget = rate - (rate * discount / 100);
    final subtotal = (subtotalTarget + (subtotalTarget * tax / 100)) * qty;

    c['netrate']!.text = netrate.toStringAsFixed(2);
    c['subtotal']!.text = subtotal.toStringAsFixed(2);
  }

  void _recalculateFromNetRate(Map<String, TextEditingController> c) {
    final netrate = double.tryParse(c['netrate']!.text) ?? 0.0;
    final tax = double.tryParse(c['tax']!.text) ?? 0.0;
    final discount = double.tryParse(c['discount']!.text) ?? 0.0;
    final qty = double.tryParse(c['qty']!.text) ?? 1.0;

    final rate = netrate / (1 + (tax / 100));
    final subtotalTarget = rate * (1 - (discount / 100));
    final subtotal = (subtotalTarget * (1 + (tax / 100))) * qty;

    c['rate']!.text = rate.toStringAsFixed(2);
    c['subtotal']!.text = subtotal.toStringAsFixed(2);
  }

  Map<String, dynamic> _collectUpdatedItem(
    Map<String, dynamic> item,
    Map<String, TextEditingController> c,
  ) {
    final rate = double.tryParse(c['rate']!.text) ?? 0.0;
    final tax = double.tryParse(c['tax']!.text) ?? 0.0;
    final discount = double.tryParse(c['discount']!.text) ?? 0.0;
    final qty = double.tryParse(c['qty']!.text) ?? 1.0;

    final netrate = rate + (rate * tax / 100);
    final subtotalTarget = rate - (rate * discount / 100);
    final subtotal = (subtotalTarget + (subtotalTarget * tax / 100)) * qty;

    return {
      'item_code': item['item_code'],
      'item_name': item['item_name'],
      'item_uom': item['item_uom'],
      'hsn_code': item['hsn_code'],
      'item_qty': int.tryParse(c['stock']!.text) ?? 0,
      'item_price1': rate,
      'item_mrp': double.tryParse(c['mrp']!.text) ?? 0.0,
      'item_tax': tax,
      'item_disc': discount,
      'qty': int.tryParse(c['qty']!.text) ?? 0,
      'free': int.tryParse(c['free']!.text) ?? 0,
      'offer': c['offer']!.text,
      'netrate': netrate,
      'subtotal': double.parse(subtotal.toStringAsFixed(2)),
    };
  }

  void _showItemDialog(Map<String, dynamic> item) {
    final c = _createControllers(item);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StatefulBuilder(
          builder: (context, setDialogState) => Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
              maxWidth: 500,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey[600], size: 24),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _dialogField('Stock', c['stock']!, enabled: false),
                          const SizedBox(height: 14),
                          _dialogField('MRP', c['mrp']!, enabled: false),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _dialogField(
                                  'Tax',
                                  c['tax']!,
                                  onChanged: (_) {
                                    _recalculateFromRate(c);
                                    setDialogState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _dialogField(
                                  'Discount',
                                  c['discount']!,
                                  onChanged: (_) {
                                    _recalculateFromRate(c);
                                    setDialogState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _dialogField(
                                  'Rate',
                                  c['rate']!,
                                  onChanged: (_) {
                                    _recalculateFromRate(c);
                                    setDialogState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _dialogField(
                                  'Net Rate',
                                  c['netrate']!,
                                  onChanged: (_) {
                                    _recalculateFromNetRate(c);
                                    setDialogState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _dialogField(
                                  'Quantity',
                                  c['qty']!,
                                  autofocus: true,
                                  onChanged: (_) {
                                    _recalculateFromRate(c);
                                    setDialogState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: _dialogField('Free', c['free']!)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _dialogField('Offer Remark', c['offer']!, maxLines: 2),
                          const SizedBox(height: 14),
                          _dialogField('Subtotal', c['subtotal']!, enabled: false),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              final updated = _collectUpdatedItem(item, c);
                              _addItemToOrder(item, updated);
                              Navigator.pop(dialogContext);
                              _showSuccessSnackBar('Added to cart');
                              setState(() => _showShopDetails = false); // jump to cart optionally
                            }
                          },
                          child: const Text(
                            'Add',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
 double _calculateVisibleTotal() {
  return _filteredItems.fold(0.0, (total, item) {
    final rate = _getItemRate(item);
    return total + rate;
  });
}


Widget _totalBar() {
  final total = _calculateVisibleTotal();
  final showingSearch = _searchController.text.trim().isNotEmpty;

  return Container(
   padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), // ⬅ more space under total

    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Center(
            child: Text(
              showingSearch
                  ? "Search Total: ₹${total.toStringAsFixed(2)}"
                  : "Total: ₹${total.toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}



  Widget _dialogField(
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
      keyboardType: isOffer ? TextInputType.multiline : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? Colors.grey[50] : Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: onChanged,
      validator: (value) {
        if (label.toLowerCase() == 'quantity' && (value == null || value.isEmpty)) return 'Required';
        return null;
      },
    );
  }

  Future<void> _confirmDeleteItem(Map<String, dynamic> item) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Item'),
        content: Text('Remove ${item['item_name']} from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              _deleteItem(item);
              Navigator.pop(context);
            },
            child: const Text('Remove',style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Stock",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _fetchStocks,
            icon: const Icon(Icons.refresh, color: Color(0xFF6C63FF)),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _searchBar(),
          const SizedBox(height: 12),
          Expanded(child: _isLoading ? const ListLoading() : _buildItemList()),
          _totalBar(),
        ],
      ),

    );
  }
}
