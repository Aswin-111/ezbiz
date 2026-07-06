// lib/widgets/user_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Header with search bar for the customer directory.
///
/// Owns a persistent [TextEditingController] on its own State so the field
/// isn't rebuilt/re-wired on every parent `setState`. This preserves cursor
/// position, selection, and focus when the parent triggers a rebuild
/// (e.g. debounced search or loading-state toggle).
class UserHeader extends StatefulWidget {
  final String searchText;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onLogoutPressed;

  const UserHeader({
    Key? key,
    required this.searchText,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onLogoutPressed,
  }) : super(key: key);

  @override
  State<UserHeader> createState() => _UserHeaderState();
}

class _UserHeaderState extends State<UserHeader> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchText);
  }

  @override
  void didUpdateWidget(covariant UserHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync from parent if the parent forced a different value (e.g. clear
    // search), but don't stomp on the caret while the user is typing —
    // only assign when the value truly differs.
    if (widget.searchText != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.searchText,
        selection: TextSelection.collapsed(offset: widget.searchText.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 15.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Menu Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Builder(
                      builder: (context) => IconButton(
                        icon: Icon(Icons.menu_rounded,
                            color: Colors.white, size: 24.sp),
                        onPressed: () {
                          Scaffold.of(context).openDrawer();
                        },
                      ),
                    ),
                  ),
                  // Title
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Welcome Back! 👋',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          'Customers Directory',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Logout Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.logout_rounded,
                          color: Colors.white, size: 24.sp),
                      onPressed: widget.onLogoutPressed,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 25.h),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  onChanged: widget.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    hintStyle:
                        TextStyle(color: Colors.grey[400], fontSize: 15.sp),
                    border: InputBorder.none,
                    prefixIcon: Container(
                      padding: EdgeInsets.all(12.w),
                      child: Icon(Icons.search_rounded,
                          color: Color(0xFF6C63FF), size: 24.sp),
                    ),
                    suffixIcon: widget.searchText.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[400]),
                            onPressed: widget.onClearSearch,
                          )
                        : null,
                    contentPadding: EdgeInsets.symmetric(
                        vertical: 17.h, horizontal: 20.w),
                  ),
                  style: TextStyle(
                      color: Colors.black87, fontSize: 15.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
