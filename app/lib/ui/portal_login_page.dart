import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_state.dart';

/// The school's official CAS page handles the password. After a successful
/// SSO redirect we only read timetable-cfc cookies, never form fields.
class PortalLoginPage extends StatefulWidget {
  final AppState state;
  final String studentId;

  const PortalLoginPage({
    super.key,
    required this.state,
    required this.studentId,
  });

  @override
  State<PortalLoginPage> createState() => _PortalLoginPageState();
}

class _PortalLoginPageState extends State<PortalLoginPage> {
  static final Uri _service = Uri.parse(
    'https://timetable-cfc.cqut.edu.cn/api/auth/casLogin',
  );
  static final Uri _login = Uri.https(
    'uis.cqut.edu.cn',
    '/center-auth-server/YF8A4013/cas/login',
    {'service': _service.toString()},
  );

  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  late final WebViewController _controller;
  Timer? _pollTimer;
  bool _checking = false;
  bool _complete = false;
  int _progress = 0;
  String? _message;
  String? _lastTriedSession;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onPageFinished: (_) => _tryConnect(),
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _message = '学校网页加载失败，请检查网络后刷新');
            }
          },
        ),
      )
      ..loadRequest(_login);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _tryConnect(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _tryConnect({bool manual = false}) async {
    if (!mounted || _checking || _complete) return;
    _checking = true;
    try {
      // Android WebView's cookie manager can read HttpOnly session cookies.
      // Only query the official timetable service's cookie scope.
      final found = await _cookieManager.getCookies(domain: _service);
      final cookies = <String, String>{};
      for (final cookie in found) {
        if (cookie.name.isNotEmpty && cookie.value.isNotEmpty) {
          cookies[cookie.name] = cookie.value;
        }
      }
      if (cookies.isEmpty) {
        if (manual && mounted) {
          setState(() => _message = '请先在学校网页完成统一身份认证');
        }
        return;
      }
      final sessionKey = cookies.entries
          .map((entry) => entry.key + '=' + entry.value)
          .join(';');
      if (!manual && sessionKey == _lastTriedSession) return;
      _lastTriedSession = sessionKey;
      if (mounted) {
        setState(() => _message = '检测到学校登录会话，正在验证课表接口…');
      }
      final ok = await widget.state.loginWithTimetableSession(
        widget.studentId,
        cookies,
      );
      if (!mounted) return;
      if (ok) {
        _complete = true;
        _pollTimer?.cancel();
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _message = widget.state.error ?? '课表认证失败，请完成官方登录后重试';
        });
      }
    } catch (_) {
      if (mounted && manual) {
        setState(() => _message = '读取课表会话失败，请刷新学校网页重试');
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('重庆理工大学统一身份认证'),
        actions: [
          IconButton(
            tooltip: '重新加载',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _lastTriedSession = null;
              _controller.reload();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100)
            LinearProgressIndicator(value: _progress / 100),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _message!,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _checking ? null : () => _tryConnect(manual: true),
                  child: Text(_checking ? '验证中…' : '已完成学校登录，获取课表'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
