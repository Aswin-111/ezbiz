

// lib/widgets/app_drawer.dart
import 'package:ezbiz/pages/create_cus.dart';
import 'package:ezbiz/pages/order_history.dart';
import 'package:ezbiz/pages/stock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback onLogoutTap;
 final Future<void> Function()? onCustomerCreated; 
  const AppDrawer({
    Key? key,
    required this.onLogoutTap,
     this.onCustomerCreated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Drawer Header with Gradient
          Container(
            width: double.infinity,
            height: 250.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.business_center_rounded,
                        size: 40.sp,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'EzBiz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      'Business Management',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              children: [
                // _buildDrawerItem(
                //   icon: Icons.shopping_cart_rounded,
                //   title: 'Start Ordering',
                //   subtitle: 'Create new orders',
                //   onTap: () {
                //     Navigator.pop(context);
                //     // Already on this page
                //   },
                // ),
                // _buildDrawerItem(
                //   icon: Icons.person_add_rounded,
                //   title: 'Customer Creation',
                //   subtitle: 'Add new customers',
                //   onTap: () {
                //     Navigator.pop(context);
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder: (context) => const CreateCustomerPage(),
                //       ),
                //     );
                //   },
                // ),
                _buildDrawerItem(
  icon: Icons.person_add_rounded,
  title: 'Customer Creation',
  subtitle: 'Add new customers',
  onTap: () async {
    Navigator.pop(context);

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateCustomerPage(),
      ),
    );

    if (created == true) {
      await onCustomerCreated?.call(); // ✅ refresh list
    }
  },
),

                Divider(height: 1, thickness: 1, color: Colors.grey[200]),
               _buildDrawerItem(
  icon: Icons.receipt_long_rounded,
  title: 'Order History',
  subtitle: 'View past orders',
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrderHistoryPage(),
      ),
    );
  },
),

                _buildDrawerItem(
  icon: Icons.inventory_rounded,
  title: 'Stock',
  subtitle: 'View stock & subtotal',
  onTap: () async {
    Navigator.pop(context);

    // If you already have compCode & custType available globally pass directly.
    // Otherwise read from prefs:
    final prefs = await SharedPreferences.getInstance();
    final compCode = prefs.getString('comp_code') ?? "";
    final custType = "R"; // or from prefs/logic

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockPage(compCode: compCode, custType: custType),
      ),
    );
  },
),


                // _buildDrawerItem(
                //   icon: Icons.inventory_rounded,
                //   title: 'Inventory',
                //   subtitle: 'Manage stock',
                //   onTap: () {
                //     Navigator.pop(context);
                //     // TODO: navigate to inventory
                //   },
                // ),
                // _buildDrawerItem(
                //   icon: Icons.people_rounded,
                //   title: 'Customers',
                //   subtitle: 'Manage customer data',
                //   onTap: () {
                //     Navigator.pop(context);
                //     // Already on this page
                //   },
                // ),
                // Divider(height: 1, thickness: 1, color: Colors.grey[200]),
                // _buildDrawerItem(
                //   icon: Icons.settings_rounded,
                //   title: 'Settings',
                //   subtitle: 'App preferences',
                //   onTap: () {
                //     Navigator.pop(context);
                //     // TODO: navigate to settings
                //   },
                // ),
                // _buildDrawerItem(
                //   icon: Icons.help_rounded,
                //   title: 'Help & Support',
                //   subtitle: 'Get assistance',
                //   onTap: () {
                //     Navigator.pop(context);
                //     // TODO: navigate to help
                //   },
                // ),
              ],
            ),
          ),

          // Logout at Bottom
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: ListTile(
              leading: Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Color(0xFFFFE5EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFFF6B9D),
                  size: 24.sp,
                ),
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                'Sign out of your account',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onLogoutTap();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding:
          EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
      leading: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Color(0xFFEEEDFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Color(0xFF6C63FF),
          size: 24.sp,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12.sp,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16.sp,
        color: Colors.grey[400],
      ),
      onTap: onTap,
    );
  }
}
