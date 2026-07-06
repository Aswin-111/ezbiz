import 'dart:convert';

import 'package:ezbiz/Consts/consts.dart';
import 'package:ezbiz/helper/helper.dart';
import 'package:ezbiz/models/my_sessions_response.dart';
import 'package:ezbiz/models/session_info.dart';
import 'package:ezbiz/widgets/list_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class MyDevicesPage extends StatefulWidget {
  const MyDevicesPage({Key? key}) : super(key: key);

  @override
  State<MyDevicesPage> createState() => _MyDevicesPageState();
}

class _MyDevicesPageState extends State<MyDevicesPage> {
  bool _isLoading = true;
  int? _limit;
  int? _activeCount;
  List<SessionInfo> _sessions = [];
  String? _currentSessionId;
  String? _errorMessage;
  final Set<String> _revoking = {};

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final headers = await authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/my-sessions'),
        headers: headers,
      );

      if (response.statusCode == 401) {
        clearAuthAndNavigateToLogin();
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to load sessions (${response.statusCode})');
      }

      final parsed = MySessionsResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      final currentId = await AuthStorage.getSessionId();

      if (!mounted) return;
      setState(() {
        _limit = parsed.limit;
        _activeCount = parsed.activeCount;
        _sessions = parsed.sessions;
        _currentSessionId = currentId;
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _revokeSession(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Log out this device?'),
        content: const Text(
          'This device will need to log in again to continue using the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B9D),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _revoking.add(sessionId));
    try {
      final headers = await authHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/my-sessions/$sessionId'),
        headers: headers,
      );

      if (response.statusCode == 401) {
        clearAuthAndNavigateToLogin();
        return;
      }

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to revoke (${response.statusCode})');
      }

      // If the user revoked their own current session, force them to login.
      if (sessionId == _currentSessionId) {
        clearAuthAndNavigateToLogin();
        return;
      }

      await _fetchSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFE57373),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _revoking.remove(sessionId));
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FE),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Devices',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchSessions,
            icon: const Icon(Icons.refresh, color: Color(0xFF6C63FF)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSessions,
        color: const Color(0xFF6C63FF),
        child: _isLoading
            ? const ListLoading()
            : _errorMessage != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 60.h),
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                Icon(Icons.error_outline,
                    size: 60.sp, color: Colors.red.shade300),
                SizedBox(height: 12.h),
                Text(
                  _errorMessage ?? 'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                ),
                SizedBox(height: 16.h),
                ElevatedButton.icon(
                  onPressed: _fetchSessions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      children: [
        _summaryCard(),
        SizedBox(height: 12.h),
        if (_sessions.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 40.h),
            child: Center(
              child: Text(
                'No active sessions.',
                style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
              ),
            ),
          )
        else
          ..._sessions.map(_sessionCard).toList(),
      ],
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: const BoxDecoration(
              color: Color(0xFF6C63FF),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.devices, color: Colors.white, size: 24.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_activeCount ?? _sessions.length} active device'
                  '${(_activeCount ?? _sessions.length) == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (_limit != null)
                  Text(
                    'Limit: $_limit devices',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[700],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(SessionInfo s) {
    final sessionId = s.sessionId;
    final label = s.deviceLabel;
    final lastActive = _formatRelative(s.lastActive);
    final issuedAt = _formatRelative(s.issuedAt);
    final isCurrent = sessionId == _currentSessionId;
    final isRevoking = _revoking.contains(sessionId);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.smartphone,
              color: const Color(0xFF6C63FF), size: 26.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'This device',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  'Last active: $lastActive',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  'Signed in: $issuedAt',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8.h),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: isRevoking || sessionId.isEmpty
                        ? null
                        : () => _revokeSession(sessionId),
                    icon: isRevoking
                        ? SizedBox(
                            width: 14.w,
                            height: 14.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF6B9D),
                            ),
                          )
                        : Icon(Icons.logout,
                            size: 16.sp, color: const Color(0xFFFF6B9D)),
                    label: Text(
                      isCurrent
                          ? 'Log out of this device'
                          : 'Log out this device',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFFFF6B9D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
