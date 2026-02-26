// lib/pages/user_data_page.dart
import 'dart:convert';
import 'package:ezbiz/Consts/consts.dart';
import 'package:ezbiz/HomeWidgets/area_dropdown.dart';
import 'package:ezbiz/HomeWidgets/user_header.dart';
import 'package:ezbiz/HomeWidgets/area_filter_pills.dart';
import 'package:ezbiz/HomeWidgets/customer_list.dart';
import 'package:ezbiz/HomeWidgets/app_drawer.dart';
import 'package:ezbiz/HomeWidgets/logout_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class UserDataPage extends StatefulWidget {
  @override
  _UserDataPageState createState() => _UserDataPageState();
}

class _UserDataPageState extends State<UserDataPage> {
  List<dynamic> _users = [];
  List<String> _areas = [];
  String? _selectedArea = "All";
  String _searchName = '';
  bool _isLoading = true;
  String? _compCode;
  int _page = 1;
final int _limit = 10;
bool _isInitialLoading = true;   // first load shimmer
bool _isPageLoading = false;     // bottom loader for next pages
bool _hasMore = true;            // stop when no more data

String _norm(dynamic v) => (v ?? '').toString().trim().toLowerCase();

List<dynamic> get _filteredUsers {
  final selected = _norm(_selectedArea ?? "All");
  final q = _norm(_searchName);

  return _users.where((user) {
    final name = _norm(user['cust_name']);

    // ✅ prefer cust_area (common in ERP apps)
    final custArea = _norm(user['cust_area']);

    // fallback to address if area missing
    final address = _norm(user['cust_address']);

    final matchesName = q.isEmpty || name.contains(q);

    final matchesArea = selected == "all"
        ? true
        : (custArea.isNotEmpty
            ? custArea == selected
            : address.contains(selected));

    return matchesName && matchesArea;
  }).toList();
}



  @override
  void initState() {
    super.initState();
    _loadCompCodeAndFetchData();
  }

  Widget _buildShimmerLoading() {
  return Column(
    children: [
      // Optional top padding to mimic header spacing
      SizedBox(height: 20.h),
      // Shimmer list
      Expanded(
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          itemCount: 6, // number of skeleton items
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(bottom: 15.h),
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  height: 90.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      // Avatar skeleton
                      Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Container(
                          width: 60.w,
                          height: 60.w,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      // Text skeletons
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 140.w,
                              height: 12.h,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              width: 200.w,
                              height: 10.h,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Container(
                              width: 120.w,
                              height: 10.h,
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


  Future<void> _loadCompCodeAndFetchData() async {
  final prefs = await SharedPreferences.getInstance();
  _compCode = prefs.getString('comp_code');

  if (_compCode == null || _compCode!.isEmpty) {
    print("Error: comp_code not found in SharedPreferences");
    setState(() => _isInitialLoading = false);
    return;
  }

  await _refreshAndFetchFirstPage();
}


  Future<Map<String, String>> _getAuthHeaders() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');

  if (token == null || token.isEmpty) {
    throw Exception("Auth token missing");
  }

  return {
    "Content-Type": "application/json",
    "Authorization": "Bearer $token",
  };
}



//   Future<void> _fetchData() async {
//   try {
//     final headers = await _getAuthHeaders();

//     final response = await http.get(
//       Uri.parse('$baseUrl/allcust'),
//       headers: headers,
//     );

//     if (response.statusCode == 200) {
//       final jsonData = json.decode(response.body);
//       setState(() {
//         _users = jsonData['users'];
//         _areas = ["All", ...List<String>.from(jsonData['areas'])];
//         _isLoading = false;
//       });
//     } else {
//       print('Failed to load data: ${response.statusCode}');
//       setState(() => _isLoading = false);
//     }
//   } catch (e) {
//     print('Error fetching data: $e');
//     setState(() => _isLoading = false);
//   }
// }

Future<void> _refreshAndFetchFirstPage() async {
  setState(() {
    _page = 1;
    _hasMore = true;
    _users.clear();
    _areas.clear();
    _isInitialLoading = true;
  });

  await _fetchPage(page: 1);

  if (mounted) {
    setState(() => _isInitialLoading = false);
  }
}

Future<void> _fetchNextPage() async {
  if (_isPageLoading || !_hasMore || _isInitialLoading) return;
  await _fetchPage(page: _page + 1);
}

Future<void> _fetchPage({required int page}) async {
  try {
    setState(() => _isPageLoading = true);

    final headers = await _getAuthHeaders();

    final uri = Uri.parse(
      '$baseUrl/allcust?comp_code=$_compCode&page=$page&limit=$_limit',
    );

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);

      final List<dynamic> newUsers =
          (jsonData['users'] as List<dynamic>?) ?? [];

      // ✅ areas only from first page (optional but recommended)
      if (page == 1) {
        final List<dynamic> apiAreas =
            (jsonData['areas'] as List<dynamic>?) ?? [];
        _areas = ["All", ...apiAreas.map((e) => e.toString()).toList()];
      }

      setState(() {
        _page = page;
        _users.addAll(newUsers);

        // ✅ stop if API returned less than limit (no more pages)
        if (newUsers.length < _limit) {
          _hasMore = false;
        }
      });
    } else if (response.statusCode == 401) {
      throw Exception("Unauthorized (token expired/invalid)");
    } else {
      throw Exception("Failed to load data: ${response.statusCode}");
    }
  } catch (e) {
    print("Error fetching page $page: $e");
    // optional: show snackbar
  } finally {
    if (mounted) setState(() => _isPageLoading = false);
  }
}



  int get _filteredResultsCount => _filteredUsers.length;
  


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ScreenUtilInit(
        designSize: Size(375, 812),
        child: Scaffold(
          backgroundColor: Color(0xFFF8F9FE),
          // drawer: AppDrawer(
          //   onLogoutTap: () => showLogoutConfirmationDialog(context),
          // ),
          drawer: AppDrawer(
  onLogoutTap: () => showLogoutConfirmationDialog(context),
  onCustomerCreated: () async {
    await _refreshAndFetchFirstPage(); // ✅ reload page 1
  },
),

          body: _isInitialLoading
    ? _buildShimmerLoading()
    : Column(
        children: [
          UserHeader(
            searchText: _searchName,
            onSearchChanged: (value) {
              setState(() {
                _searchName = value;
              });
            },
            onClearSearch: () {
              setState(() {
                _searchName = '';
              });
            },
            onLogoutPressed: () =>
                showLogoutConfirmationDialog(context),
          ),
          // Container(
          //   margin: EdgeInsets.only(top: 20.h),
          //   height: 50.h,
          //   child: AreaFilterPills(
          //     areas: _areas,
          //     selectedArea: _selectedArea,
          //     onAreaSelected: (area) {
          //       setState(() {
          //         _selectedArea = area;
          //       });
          //     },
          //   ),
          // ),
          SizedBox(height: 16.h),

AreaSearchDropdown(
  areas: _areas,
  selectedArea: _selectedArea ?? "All",
  onChanged: (area) {
    setState(() {
      _selectedArea = area;
    });
  },
),

SizedBox(height: 10.h),

          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 20.w, vertical: 20.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Customers',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Color(0xFFEEEDFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_filteredResultsCount Results',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
         Expanded(
  child: Stack(
    children: [
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Trigger when near bottom
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 200) {
            _fetchNextPage();
          }
          return false;
        },
        child: CustomerList(
  users: _filteredUsers,   // ✅ already filtered
  searchName: '',          // ✅ prevent double filtering inside CustomerList
  selectedArea: 'All',     // ✅ prevent double filtering inside CustomerList
),


      ),

      // Bottom loader for next page
      if (_isPageLoading && !_isInitialLoading)
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              height: 24,
              width: 24,
              child: const CircularProgressIndicator(strokeWidth: 2),
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
