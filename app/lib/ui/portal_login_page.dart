import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_state.dart';

/// The only page that loads the school's website. The rest of the app is native.
class PortalLoginPage extends StatefulWidget {
  final AppState state;
  const PortalLoginPage({super.key, required this.state});

  @override
  State<PortalLoginPage> createState() => _PortalLoginPageState();
}

class _PortalLoginPageState extends State<PortalLoginPage> {
  static final Uri _portal = Uri.parse('https://ehall.cqut.edu.cn/new_office_hall/');
  static const String _tokenScript = r'''
(() => {
  if (location.hostname.toLowerCase() !== 'ehall.cqut.edu.cn') return '';
  const keys = ['new_office_hall_token', '_yh_office_token', 'ump_token_pc-officeHall'];
  for (const key of keys) {
    const raw = window.localStorage.getItem(key);
    if (!raw || raw === 'null' || raw === 'undefined') continue;
    try {
      const parsed = JSON.parse(raw);
      if (typeof parsed === 'string' && parsed) return parsed;
      if (parsed && typeof parsed.token === 'string') return parsed.token;
    } catch (_) {}
    return raw;
  }
  return '';
})()
''';

  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  late final WebViewController _controller;
  Timer? _pollTimer;
  bool _trying = false;
  bool _finished = false;
  int _progress = 0;
  String? _message;
  String? _attemptedToken;

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
          onPageFinished: (_) => _checkToken(),
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _message = '学校网页加载失败，请检查网络后重试');
            }
          },
        ),
      )
      ..loadRequest(_portal);

    // The office hall is a SPA: localStorage may be written after onPageFinished.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkToken());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkToken({bool manual = false}) async {
    if (_trying || _finished || !mounted) return;
    try {
      final url = await _controller.currentUrl();
      if (url == null || Uri.tryParse(url)?.host != _portal.host) {
        if (manual && mounted) {
          setState(() => _message = '请先在学校网页完成登录，再返回网上办事大厅');
        }
        return;
      }

      final result = await _controller.runJavaScriptReturningResult(_tokenScript);
      var token = result.toString();
      // iOS and Android WebView implementations may encode JS strings differently.
      if (token.startsWith('"') && token.endsWith('"')) {
        try {
          final decoded = jsonDecode(token);
          if (decoded is String) token = decoded;
        } catch (_) {}
      }
      if (token.isEmpty || token == 'null' || token == 'undefined') {
        if (manual && mounted) {
          setState(() => _message = '尚未读取到门户登录凭证，请确认已进入网上办事大厅首页');
        }
        return;
      }
      // An invalid token should not generate network requests every two seconds.
      if (!manual && token == _attemptedToken) return;
      _attemptedToken = token;
      _trying = true;
      if (mounted) setState(() => _message = '已检测到门户会话，正在连接课程服务…');

      final cookies = <String, String>{};
      try {
        for (final item in await _cookieManager.getCookies(domain: _portal)) {
          if (item.name.isNotEmpty && item.value.isNotEmpty) {
            cookies[item.name] = item.value;
          }
        }
      } catch (_) {
        // Some WebView implementations cannot enumerate cookies. The token
        // header remains the primary authentication mechanism.
      }

      final ok = await widget.state.loginWithPortalToken(token, cookies: cookies);
      if (!mounted) return;
      if (ok) {
        _finished = true;
        _pollTimer?.cancel();
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _message = widget.state.error ?? '连接课程服务失败，请重新登录');
    } catch (_) {
      if (mounted && manual) {
        setState(() => _message = '未能读取学校网页会话，请刷新网页重试');
      }
    } finally {
      _trying = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学校统一身份认证'),
        actions: [
          IconButton(
            tooltip: '重新加载',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _attemptedToken = null;
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                _message!,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.state.error == null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
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
                  onPressed: _trying ? null : () => _checkToken(manual: true),
                  child: Text(_trying ? '连接中…' : '已完成学校登录，继续'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
