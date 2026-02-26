import 'dart:convert';
import 'package:ezbiz/Consts/consts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TestUserDetailsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String compCode;
  final String custType;

  const TestUserDetailsPage({
    Key? key,
    required this.userData,

    required this.compCode,
    required this.custType,
  }) : super(key: key);

  @override
  _TestUserDetailsPageState createState() => _TestUserDetailsPageState();
}

class _TestUserDetailsPageState extends State<TestUserDetailsPage> {
  final _formKey = GlobalKey<FormState>(); 
  TextEditingController _searchController = TextEditingController();
  double itemTotal = 0;
  List<Map<String, dynamic>> _userDetails = [];
  List<Map<String, dynamic>> _filteredDetails = [];
  bool _isLoading = true;
  bool _showShopDetails = false;
  List<Map<String, dynamic>> _addedItems = [];
  List<Map<String, TextEditingController>> controllers = [];

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shopdetails'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"comp_code": widget.compCode}),
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
        _showError("Failed to fetch details. Status: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error fetching data: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    setState(() {
      _isLoading = false;
    });
  }

  void _filterSearchResults(String query) {
    setState(() {
      _filteredDetails = query.isEmpty
          ? List.from(_userDetails)
          : _userDetails.where((item) {
              final name = (item['item_name'] ?? '').toString().toLowerCase();
              return name.contains(query.toLowerCase());
            }).toList();
    });
  }

  String formatNumber(double number) {
    return number >= 30000 ? '${(number / 1000).toStringAsFixed(1)}k' : number.toStringAsFixed(2);
  }

  double _calculateTotal() {
    return _addedItems.fold(0.0, (total, item) {
      final quantity = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
      final price = double.tryParse(item['item_price1']?.toString() ?? '0') ?? 0;
      return total + (quantity * price);
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onTap: () {
          setState(() {
            _showShopDetails = true;
          });
        },
        onChanged: _filterSearchResults,
        decoration: InputDecoration(
          hintText: 'Search Item',
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _filterSearchResults('');
                  },
                )
              : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildItemList() {
    return _filteredDetails.isNotEmpty
        ? ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredDetails.length,
            itemBuilder: (context, index) {
              final item = _filteredDetails[index];
              return _buildItemCard(item);
            },
          )
        : const Center(
            child: Text("No Data Found", style: TextStyle(fontSize: 16, color: Colors.grey)));
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['item_name'] ?? 'No Name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 6.h),
              Text("Stock: ${item['item_qty'] ?? 'N/A'}  |  Price: ${item['item_price1'] ?? 'N/A'}", style: const TextStyle(fontSize: 14)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.blue),
            onPressed: () {
              showItemDialog(context, item, _addItemToOrder);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddedItemList() {
    return _addedItems.isNotEmpty
        ? ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _addedItems.length,
            itemBuilder: (context, index) {
              final item = _addedItems[index];
              double quantity = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
              double price = double.tryParse(item['item_price1']?.toString() ?? '0') ?? 0;
              itemTotal = price;
              return _buildAddedItemCard(item, quantity, price);
            },
          )
        : const Center(
            child: Text("No items added yet.", style: TextStyle(fontSize: 16, color: Colors.grey)));
  }

  Widget _buildAddedItemCard(Map<String, dynamic> item, double quantity, double price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['item_name'] ?? 'No Name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 6.h),
              Text("Quantity: ${item['qty'] ?? 'N/A'}  |  Total: ₹${itemTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14)),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () {
                  showItemDialog(context, item, _addItemToOrder);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDeleteItem(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    String? custType = widget.custType;
    Color badgeColor = Colors.transparent;
    String badgeText = '';

    if (custType == 'R') {
      badgeColor = const Color(0xFFCDFD5D);
      badgeText = 'R';
    } else if (custType == 'W') {
      badgeColor = const Color(0xFFE579B9);
      badgeText = 'W';
    }

    return Stack(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF8C8DF7),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userData['cust_name'],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                "Address: ${widget.userData['cust_address']}",
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
              Text(
                "Phone: ${widget.userData['cust_phone']}",
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
            ],
          ),
        ),
        if (badgeText.isNotEmpty)
          Positioned(
            top: 35,
            right: 35,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 25),
              ),
            ),
          ),
      ],
    );
  }

  void showItemDialog(BuildContext context, Map<String, dynamic> item, Function(Map<String, dynamic>, Map<String, dynamic>) onAddItem) {
    final controllers = _createControllers(item);
    final focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controllers['qty']!.selection = TextSelection(baseOffset: 0, extentOffset: controllers['qty']!.text.length);
      FocusScope.of(context).requestFocus(focusNode);
    });


   showDialog(
  context: context,
  builder: (context) {
    return AlertDialog(
      title: Text('${item['item_name'] ?? "Edit Item"}'),
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey, // Assuming you have a GlobalKey<FormState> _formKey
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInputField('Stock', controllers['stock']!, enabled: false),
                const SizedBox(height: 12),
                _buildInputField('MRP', controllers['mrp']!, enabled: false),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField('Tax', controllers['tax']!),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInputField('Discount', controllers['discount']!),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField('Rate', controllers['rate']!),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInputField('Net Rate', controllers['netrate']!),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField('Quantity', controllers['qty']!, focusNode: focusNode),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInputField('Free', controllers['free']!),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInputField('Offer Remark', controllers['offer']!),
                const SizedBox(height: 12),
                _buildInputField('Subtotal', controllers['subtotal']!, enabled: false),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final updatedItem = _collectUpdatedItem(item, controllers);
              onAddItem(item, updatedItem);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Item added successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  },
);
  }

  Map<String, TextEditingController> _createControllers(Map<String, dynamic> item) {
    return {
      'stock': TextEditingController(text: item['item_qty']?.toString() ?? ''),
      'mrp': TextEditingController(text: item['item_mrp']?.toString() ?? ''),
      'tax': TextEditingController(text: item['item_tax']?.toString() ?? ''),
      'rate': TextEditingController(text: item['item_price1']?.toString() ?? ''),
      'netrate': TextEditingController(text: item['netrate']?.toString() ?? ''),
      'qty': TextEditingController(text: item['qty']?.toString() ?? '1'),
      'free': TextEditingController(text: item['free']?.toString() ?? ''),
      'discount': TextEditingController(text: item['discount']?.toString() ?? '0'),
      'offer': TextEditingController(text: item['offer'] ?? ''),
      'subtotal': TextEditingController(text: item['subtotal']?.toString() ?? ''),
    };
  }

  Map<String, dynamic> _collectUpdatedItem(Map<String, dynamic> item, Map<String, TextEditingController> controllers) {
    final rate = double.tryParse(controllers['rate']!.text) ?? 0.0;
    final tax = double.tryParse(controllers['tax']!.text) ?? 0.0;
    final discount = double.tryParse(controllers['discount']!.text) ?? 0.0;
    final quantity = double.tryParse(controllers['qty']!.text) ?? 1.0;

    final netrate = rate + (rate * tax / 100);
    final subtotalTarget = rate - (rate * discount / 100);
    final subtotal = (subtotalTarget + (subtotalTarget * tax / 100)) * quantity;

    return {
      'item_name': item['item_name'],
      'item_qty': int.tryParse(controllers['stock']!.text) ?? 0,
      'item_price1': double.tryParse(controllers['rate']!.text) ?? 0.0,
      'qty': int.tryParse(controllers['qty']!.text) ?? 0,
      'free': int.tryParse(controllers['free']!.text) ?? 0,
      'offer': controllers['offer']!.text,
      'discount': double.tryParse(controllers['discount']!.text) ?? 0.0,
      'item_mrp': double.tryParse(controllers['mrp']!.text) ?? 0.0,
      'item_tax': double.tryParse(controllers['tax']!.text) ?? 0.0,
      'netrate': netrate,
      'subtotal': subtotal,
    };
  }

 Widget _buildInputField(String label, TextEditingController controller, {FocusNode? focusNode, bool enabled = true}) {
  return TextFormField(
    focusNode: focusNode,
    controller: controller,
    enabled: enabled,
    keyboardType: label.toLowerCase() == 'offer remark' ? TextInputType.multiline : TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        //borderRadius: BorderRadius.circular(8)
        ),
      suffixIcon: null
      // controller.text.isNotEmpty
      //     ? IconButton(
      //         icon: const Icon(Icons.clear),
      //         onPressed: () {
      //           controller.clear();
      //         },
      //       )
      //     : null,
      // prefixIcon: label.toLowerCase() == 'quantity' ? const Icon(Icons.numbers) : null,
      // filled: true,
      // fillColor: enabled ? Colors.white : Colors.grey[200],
    ),
    validator: (value) {
      if (label.toLowerCase() == 'quantity' && (value == null || value.isEmpty)) {
        return 'Please enter a quantity';
      }
      return null;
    },
     onTap: () {
        // Select all text when the field is tapped
        if (enabled) {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.value.text.length,
          );
        }
      },
  );
}

  Future<void> _addItemToOrder(Map<String, dynamic> oldItem, Map<String, dynamic> newItem) async {
    setState(() {
      final index = _addedItems.indexWhere((element) => element['item_name'] == oldItem['item_name']);
      if (index >= 0) {
        _addedItems[index] = newItem;
      } else {
        _addedItems.add(newItem);
      }
    });
  }

  Future<void> _submitOrder() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');

    final requestBody = {
      'comp_code': widget.compCode,
      'user_id': userId,
      'order_details': _addedItems,
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _addedItems.clear();
          _showShopDetails = false;
        });

        _fetchUserDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit order. Status: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteItem(Map<String, dynamic> item) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete ${item['item_name']}?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                _deleteItem(item);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteItem(Map<String, dynamic> item) {
    setState(() {
      _addedItems.removeWhere((element) => element['item_name'] == item['item_name']);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item deleted successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            SizedBox(height: 100.h),
            _buildCustomerInfo(),
            _buildSearchBar(),
            SizedBox(height: 10.h),
            if (_showShopDetails)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _showShopDetails = false;
                            });
                          },
                        ),
                      ],
                    ),
                    Expanded(
                      child: _isLoading ? _buildLoadingIndicator() : _buildItemList(),
                    ),
                  ],
                ),
              ),
            if (!_showShopDetails && _addedItems.isNotEmpty)
              Expanded(child: _buildAddedItemList()),
            if (!_showShopDetails && _addedItems.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    "Click on search bar to show items",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ),
            if (!_showShopDetails && _addedItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8C8DF7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                 
                  onPressed: (){},
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Add Order',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '₹${_calculateTotal().toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}