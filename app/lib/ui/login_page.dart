import 'package:flutter/material.dart';

import '../app_state.dart';
import 'portal_login_page.dart';

/// Only the student ID is entered in our app. Password stays in official CAS.
class LoginPage extends StatefulWidget {
  final AppState state;
  const LoginPage({super.key, required this.state});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _studentId = TextEditingController();

  @override
  void initState() {
    super.initState();
    _studentId.text = widget.state.account?.username ?? '';
  }

  @override
  void dispose() {
    _studentId.dispose();
    super.dispose();
  }

  Future<void> _openPortal() async {
    final id = _studentId.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写学号')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PortalLoginPage(
          state: widget.state,
          studentId: id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2F5BFF), Color(0xFF6E8BFF)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '知',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    '知行闪课',
                    style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '课表来自学校官方接口，打开直接读取本地缓存',
                    style: TextStyle(fontSize: 14, color: Color(0xFF7A8099)),
                  ),
                  const SizedBox(height: 36),
                  TextField(
                    controller: _studentId,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _openPortal(),
                    decoration: InputDecoration(
                      labelText: '学号',
                      hintText: '填写学校统一身份认证的学号',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '下一步打开重庆理工大学官方统一身份认证页面。'
                    '请直接在官方网页输入密码；登录后自动获取课表。',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  if (widget.state.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.state.error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _openPortal,
                      child: const Text('前往学校官方登录'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '密码仅在学校官方网页中输入；本应用不会读取或保存登录密码。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8F95A6),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
