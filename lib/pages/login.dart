
import 'dart:convert';
import 'dart:io';

import 'package:ezbiz/Consts/consts.dart';
import 'package:ezbiz/models/device_limit_error.dart';
import 'package:ezbiz/models/session_info.dart';
import 'package:ezbiz/pages/welcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with SingleTickerProviderStateMixin {
  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<http.Response> createPost(String url,
      {Map<String, String>? headers, body}) async {
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6C63FF),
                Color(0xFF8B83FF),
                Color(0xFFA5A6F6),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Animated background circles
              _buildBackgroundCircles(),
              
              // Main content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 30.w),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // Logo Section
                            Center(
                              child: Container(
                                height: 110.h,
                                width: 110.w,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 30,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.business_center_rounded,
                                  size: 55.sp,
                                  color: Color(0xFF6C63FF),
                                ),
                              ),
                            ),
                            SizedBox(height: 50.h),
                            
                            // Welcome Text
                            Text(
                              'Welcome Back',
                              style: TextStyle(
                                fontSize: 36.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'Login to continue your business',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 50.h),
                            
                            // Login Card
                            Container(
                              padding: EdgeInsets.all(28.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Username Field
                                  _buildModernTextField(
                                    'Username',
                                    Icons.person_outline_rounded,
                                    username,
                                  ),
                                  SizedBox(height: 20.h),
                                  
                                  // Password Field
                                  _buildModernTextField(
                                    'Password',
                                    Icons.lock_outline_rounded,
                                    password,
                                    obscureText: _obscurePassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Color(0xFF6C63FF),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  
                                  // Forgot Password
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        // Handle forgot password
                                      },
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: Color(0xFF6C63FF),
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 24.h),
                                  
                                  // Login Button
                                  Container(
                                    width: double.infinity,
                                    height: 58.h,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18.r),
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF6C63FF),
                                          Color(0xFF8B83FF),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF6C63FF).withOpacity(0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18.r),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? SizedBox(
                                              height: 24.h,
                                              width: 24.w,
                                              child: const CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Login',
                                                  style: TextStyle(
                                                    fontSize: 18.sp,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                                SizedBox(width: 10.w),
                                                Icon(Icons.arrow_forward_rounded, size: 22.sp),
                                              ],
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundCircles() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          left: -70,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          top: 200,
          left: -40,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(
          fontSize: 16.sp,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            padding: EdgeInsets.all(12.w),
            child: Icon(
              icon,
              color: Color(0xFF6C63FF),
              size: 24.sp,
            ),
          ),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: const BorderSide(
              color: Color(0xFF6C63FF),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Color(0xFFF8F9FE),
          contentPadding: EdgeInsets.symmetric(
            vertical: 18.h,
            horizontal: 16.w,
          ),
        ),
      ),
    );
  }

  String _formatRelative(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return DateFormat('yyyy-MM-dd').format(dt.toLocal());
  }

  Future<void> _showDeviceLimitDialog(DeviceLimitError err) async {
    final message = err.message;
    final limit = err.limit;
    final sessions = err.activeSessions;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.devices_other, color: Color(0xFF6C63FF)),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Device Limit Reached',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: TextStyle(fontSize: 14.sp)),
              if (limit != null) ...[
                SizedBox(height: 8.h),
                Text(
                  'Limit: $limit devices',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              SizedBox(height: 14.h),
              Text(
                'Active sessions',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 6.h),
              if (sessions.isEmpty)
                Text(
                  'No session data returned.',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => Divider(height: 12.h),
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      final label = s.deviceLabel;
                      final lastActive = _formatRelative(s.lastActive);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.smartphone,
                              size: 18.sp, color: Color(0xFF6C63FF)),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Last active: $lastActive',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              SizedBox(height: 10.h),
              Text(
                'Please log out from another device and try again.',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'OK',
              style: TextStyle(color: Color(0xFF6C63FF)),
            ),
          ),
        ],
      ),
    );
  }

  String _deriveDeviceLabel() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'Unknown device';
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String userName = username.text;
      String userPassword = password.text;

      final http.Response response = await createPost(
        '$baseUrl/login',
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_name": userName,
          "user_password": userPassword,
          "device_label": _deriveDeviceLabel(),
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
  final data = jsonDecode(response.body) as Map<String, dynamic>;

  final token = data['token'] as String?;
  final user = data['user'] as Map<String, dynamic>?;
  final session = data['session'] as Map<String, dynamic>?;

  if (token == null || user == null) {
    throw Exception("Invalid login response: token/user missing");
  }

  final prefs = await SharedPreferences.getInstance();

  // ✅ Save token
  await prefs.setString('auth_token', token);

  // ✅ Save session id (used for POST /logout and DELETE /my-sessions/:id)
  final sessionId = session?['session_id']?.toString();
  if (sessionId != null && sessionId.isNotEmpty) {
    await AuthStorage.saveSessionId(sessionId);
  }

  // ✅ Save user fields (from nested user object)
  await prefs.setString('comp_code', user['comp_code']?.toString() ?? '');
  await prefs.setString('user_id', user['user_id']?.toString() ?? '');
  await prefs.setString('user_name', user['user_name']?.toString() ?? '');
  await prefs.setString('user_type', user['user_type']?.toString() ?? '');

  // Optional: store full response too
  await prefs.setString('login_response', jsonEncode(data));

  if (!mounted) return;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => WelcomePage()),
  );
} else if (response.statusCode == 409) {
        final err = DeviceLimitError.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        await _showDeviceLimitDialog(err);
      }

      // if (response.statusCode == 200) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Row(
      //         children: [
      //           Icon(Icons.check_circle, color: Colors.white),
      //           SizedBox(width: 12),
      //           Text('Login successful!'),
      //         ],
      //       ),
      //       backgroundColor: Color(0xFF4CAF50),
      //       behavior: SnackBarBehavior.floating,
      //       shape: RoundedRectangleBorder(
      //         borderRadius: BorderRadius.circular(15.r),
      //       ),
      //       margin: EdgeInsets.all(20),
      //     ),
      //   );

      //   print(response.body);

      //   final user = jsonDecode(response.body);
      //   final prefs = await SharedPreferences.getInstance();

      //   await prefs.setString('comp_code', user['comp_code']);
      //   await prefs.setString('user_id', user['user_id']);
      //   await prefs.setString('user_name', user['user_name']);
      //   await prefs.setString('user_type', user['user_type']);
      //   await prefs.setString('user_data', jsonEncode(user));

      //   final userData = await prefs.getString('user_data');
      //   print(["done", userData]);

      //   Navigator.pushReplacement(
      //     context,
      //     MaterialPageRoute(builder: (context) => WelcomePage()),
      //   );
      // } 
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Username or password incorrect'),
              ],
            ),
            backgroundColor: Color(0xFFFF6B9D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.r),
            ),
            margin: EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Color(0xFFFF6B9D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.r),
          ),
          margin: EdgeInsets.all(20),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
