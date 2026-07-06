import 'dart:convert';

import 'package:ezbiz/Consts/consts.dart';
import 'package:ezbiz/helper/device_id.dart';
import 'package:ezbiz/pages/welcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Device ID reveal state — loaded async after first frame; controls the
  // pre-login "Show my device ID" widget so a user can copy their ID and
  // send it to their admin before ever attempting login.
  String? _deviceId;
  bool _deviceIdVisible = false;

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

    // Prime the device ID so it's available both for the pre-login reveal
    // and (via cache) synchronously during 403 handling.
    DeviceId.get().then((id) {
      if (!mounted) return;
      setState(() => _deviceId = id);
    });
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
                                          color: Color(0xFF6C63FF)
                                              .withOpacity(0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18.r),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? SizedBox(
                                              height: 24.h,
                                              width: 24.w,
                                              child:
                                                  const CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
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
                                                Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 22.sp),
                                              ],
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: 16.h),

                                  // Pre-login device ID reveal — lets a
                                  // first-time user see and copy their ID
                                  // to send to an admin proactively.
                                  _buildDeviceIdReveal(),
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

  Widget _buildDeviceIdReveal() {
    if (_deviceIdVisible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices_other,
                  size: 16.sp, color: const Color(0xFF6C63FF)),
              SizedBox(width: 6.w),
              Text(
                'Your device ID',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _deviceIdVisible = false),
                child: Text(
                  'Hide',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FE),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _deviceId ?? 'Loading…',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.black87,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _deviceId == null ? null : _copyDeviceId,
                  icon: Icon(Icons.copy_rounded,
                      size: 18.sp, color: const Color(0xFF6C63FF)),
                  tooltip: 'Copy device ID',
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Share this ID with your admin to get your device approved.',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.center,
      child: TextButton.icon(
        onPressed: () => setState(() => _deviceIdVisible = true),
        icon: Icon(Icons.devices_other,
            size: 16.sp, color: const Color(0xFF6C63FF)),
        label: Text(
          'Show my device ID',
          style: TextStyle(
            color: const Color(0xFF6C63FF),
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _copyDeviceId() async {
    final id = _deviceId;
    if (id == null) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Device ID copied to clipboard'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
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

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userName = username.text;
      final userPassword = password.text;
      final deviceId = await DeviceId.get();

      final http.Response response = await createPost(
        '$baseUrl/login',
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_name": userName,
          "user_password": userPassword,
          "mac_address": deviceId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final token = data['token'] as String?;
        final user = data['user'] as Map<String, dynamic>?;

        if (token == null || user == null) {
          throw Exception("Invalid login response: token/user missing");
        }

        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('auth_token', token);
        await prefs.setString(
            'comp_code', user['comp_code']?.toString() ?? '');
        await prefs.setString('user_id', user['user_id']?.toString() ?? '');
        await prefs.setString('user_name', user['user_name']?.toString() ?? '');
        await prefs.setString('user_type', user['user_type']?.toString() ?? '');
        await prefs.setString('login_response', jsonEncode(data));

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => WelcomePage()),
        );
      } else if (response.statusCode == 403) {
        // Device not on the whitelist. Show the server's message and the
        // device ID the user needs to send their admin.
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final serverMessage = (data['message'] as String?) ??
            'This device is not approved.';
        // Trust the server's echoed mac_address if present, else fall back
        // to the locally-known value.
        final id = (data['mac_address'] as String?)?.trim().isNotEmpty == true
            ? data['mac_address'].toString()
            : deviceId;

        await _showNotApprovedDialog(message: serverMessage, deviceId: id);
      } else {
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
      debugPrint('Login error: $e');
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

  Future<void> _showNotApprovedDialog({
    required String message,
    required String deviceId,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: const Color(0xFF6C63FF)),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Device not approved',
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
              SizedBox(height: 14.h),
              Text(
                'Your device ID',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 6.h),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        deviceId,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.black87,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: deviceId));
                        if (!dialogCtx.mounted) return;
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                          SnackBar(
                            content: const Text(
                                'Device ID copied to clipboard'),
                            backgroundColor: const Color(0xFF4CAF50),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                            margin: const EdgeInsets.all(20),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(Icons.copy_rounded,
                          size: 18.sp,
                          color: const Color(0xFF6C63FF)),
                      tooltip: 'Copy device ID',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Send this ID to your admin. They must approve it before '
                'you can log in.',
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
              style: TextStyle(color: const Color(0xFF6C63FF)),
            ),
          ),
        ],
      ),
    );
  }
}
