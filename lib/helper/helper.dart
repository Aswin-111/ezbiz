import 'package:ezbiz/Consts/consts.dart';
import 'package:ezbiz/helper/device_id.dart';
import 'package:ezbiz/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central header builder for every authenticated API call.
///
/// Every authenticated endpoint expects both:
///  - `Authorization: Bearer <jwt>` for the user identity.
///  - `x-mac-address: <device_id>` for the backend's per-request device
///    whitelist check. If the device is un-whitelisted after login, the
///    backend rejects here with 401, which propagates to the global 401
///    handler ([clearAuthAndNavigateToLogin]) via each call site.
///
/// The login call itself must NOT use these headers — it's the one
/// unauthenticated endpoint. Call sites should build their own minimal
/// `Content-Type` header for that one request.
Future<Map<String, String>> authHeaders() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final deviceId = await DeviceId.get();

  return {
    "Content-Type": "application/json",
    if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    "x-mac-address": deviceId,
  };
}

Future<void> clearAllAuthPrefs() async {
  await AuthStorage.clearAll();
}

/// Call from any 401 response handler. Clears stored credentials and
/// navigates the user back to the login screen from anywhere in the app.
///
/// This is intentionally message-agnostic: the backend can now return a
/// 401 for any of:
///  - "No token, authorization denied"
///  - "Token is not valid"
///  - "Device identifier missing, please log in again"
///  - "This device's access has been revoked. Please contact your admin."
/// All map to the same UX — dump local state, go back to login.
void clearAuthAndNavigateToLogin() {
  clearAllAuthPrefs().then((_) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
      (route) => false,
    );
  });
}
