// lib/pages/user_data_page.dart
import 'dart:convert';
import 'package:ezbiz/Consts/consts.dart';
import 'package:ezbiz/HomeWidgets/area_dropdown.dart';
import 'package:ezbiz/HomeWidgets/user_header.dart';
import 'package:ezbiz/HomeWidgets/customer_list.dart';
import 'package:ezbiz/HomeWidgets/app_drawer.dart';
import 'package:ezbiz/HomeWidgets/logout_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ezbiz/helper/helper.dart';
import 'package:ezbiz/helper/responsive_page_size_mixin.dart';
import 'package:ezbiz/widgets/list_loading.dart';
import 'dart:async';
class UserDataPage extends StatefulWidget {
  @override
  _UserDataPageState createState() => _UserDataPageState();
}

class _UserDataPageState extends State<UserDataPage>
    with WidgetsBindingObserver, ResponsivePageSizeMixin<UserDataPage> {
  @override
  double get pageCardHeight => 105;
  @override
  double get pageOverhead => 310;

  List<dynamic> _users = [];
  List<String> _areas = [];
  List<String> _allAreas = [];
  String? _selectedArea = "All";
  String _searchName = '';
  String? _compCode;
  int _page = 1;
  // Responsive page size: computed from screen height after first frame.
  // Card ~105 px (90 px card + 15 px margin). Overhead: SafeArea(~24)
  // + UserHeader(~160) + AreaDropdown(~70) + "All Customers" row(~56) ≈ 310 px.
  int _limit = 10; // fallback; overridden in initState post-frame callback
  bool _isInitialLoading = true;
  bool _isPageLoading = false;
  bool _hasMore = true;
  Timer? _searchDebounce;
  String _norm(dynamic v) => (v ?? '').toString().trim().toLowerCase();

  int get _filteredResultsCount => _users.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _limit = computeInitialLimit();
      attachResponsivePageSize();
      _loadCompCodeAndFetchData();
    });
  }

  @override
  void onPageLimitChanged(int newLimit) {
    if (!mounted) return;
    setState(() => _limit = newLimit);
    _refreshAndFetchFirstPage();
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

      final headers = await authHeaders();

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': _limit.toString(),
      };

      final isAllSelected =
          (_selectedArea ?? "All").trim().toLowerCase() == "all";

      // ✅ send area only when not "All"
      if (!isAllSelected) {
        queryParams['area'] = (_selectedArea ?? "").trim();
      }
  if (_searchName.trim().isNotEmpty) {
      queryParams['name'] = _searchName.trim();
    }
      final uri = Uri.parse(
        '$baseUrl/allcust',
      ).replace(queryParameters: queryParams);

      print("Fetching: $uri");

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        final List<dynamic> newUsers =
            (jsonData['users'] as List<dynamic>?) ?? [];

        if (page == 1) {
          final List<dynamic> apiAreas =
              (jsonData['areas'] as List<dynamic>?) ?? [];

          final fetchedAreas = [
            "All",
            ...apiAreas
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toSet(),
          ];

          // ✅ store the full list only from unfiltered response
          if (isAllSelected && fetchedAreas.length > 1) {
            _allAreas = List<String>.from(fetchedAreas);
          }

          // ✅ always keep dropdown showing full area list
          _areas =
              _allAreas.isNotEmpty
                  ? List<String>.from(_allAreas)
                  : fetchedAreas;
        }

        setState(() {
          _page = page;
          _users.addAll(newUsers);

          if (newUsers.length < _limit) {
            _hasMore = false;
          }
        });
      } else if (response.statusCode == 401) {
        clearAuthAndNavigateToLogin();
        return;
      } else if (response.statusCode == 404) {
        if (page == 1) {
          setState(() {
            _users = [];
            _hasMore = false;
          });
        } else {
          setState(() {
            _hasMore = false;
          });
        }
      } else {
        throw Exception("Failed to load data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching page $page: $e");
    } finally {
      if (mounted) setState(() => _isPageLoading = false);
    }
  }


  
 @override
  void dispose() {
    detachResponsivePageSize();
    _searchDebounce?.cancel();
    super.dispose();
  }

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

          // UserHeader (search) and chrome are always in the tree so the
          // keyboard cursor is never dropped when a refresh begins.
          body: Column(
                    children: [
                      UserHeader(
                        searchText: _searchName,
                        onSearchChanged: (value) {
                          setState(() => _searchName = value);
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(
                            const Duration(milliseconds: 400),
                            _refreshAndFetchFirstPage,
                          );
                        },
                        onClearSearch: () {
                          _searchDebounce?.cancel();
                          setState(() => _searchName = '');
                          _refreshAndFetchFirstPage();
                        },
                        onLogoutPressed:
                            () => showLogoutConfirmationDialog(context),
                      ),
                      SizedBox(height: 16.h),
                      AreaSearchDropdown(
                        areas: _areas,
                        selectedArea: _selectedArea ?? "All",
                        onChanged: (area) async {
                          setState(() => _selectedArea = area);
                          await _refreshAndFetchFirstPage();
                        },
                      ),
                      SizedBox(height: 10.h),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 20.h,
                        ),
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
                                horizontal: 14.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEEDFF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_filteredResultsCount Results',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: const Color(0xFF6C63FF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Only the list area reacts to loading state.
                      Expanded(
                        child: _isInitialLoading
                            ? const ListLoading()
                            : Stack(
                                children: [
                                  NotificationListener<ScrollNotification>(
                                    onNotification: (notification) {
                                      if (notification.metrics.pixels >=
                                          notification
                                                  .metrics.maxScrollExtent -
                                              200) {
                                        _fetchNextPage();
                                      }
                                      return false;
                                    },
                                    child: CustomerList(
                                      users: _users,
                                      searchName: '',
                                      selectedArea: 'All',
                                    ),
                                  ),
                                  if (_isPageLoading)
                                    const Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Padding(
                                        padding: EdgeInsets.only(bottom: 16),
                                        child: PageLoadingIndicator(),
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
