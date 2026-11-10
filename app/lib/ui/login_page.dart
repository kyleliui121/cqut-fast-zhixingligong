import 'package:flutter/material.dart';

import '../app_state.dart';
import 'portal_login_page.dart';

/// Browser-based CAS login is only needed when the portal session expires.
/// This page never handles or stores the school's account password.
class LoginPage extends StatelessWidget {
  final AppState state;
  const LoginPage({super.key, required this.state});

  Future<void> _openPortal(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PortalLoginPage(state: state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                    '课表、考试、成绩，本地缓存，打开就快',
                    style: TextStyle(fontSize: 14, color: Color(0xFF7A8099)),
                  ),
                  const SizedBox(height: 44),
                  const Text(
                    '首次登录通过重庆理工大学官方网页完成。'
                    '验证后，日常查看课表直接使用本地缓存。',
                    style: TextStyle(fontSize: 14, height: 1.6),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      state.error!,
                      style: TextStyle(fontSize: 13, color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => _openPortal(context),
                      child: const Text('前往学校官方登录'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '账号密码仅在学校官方登录网页中填写；'
                    '本应用不会读取或保存登录密码。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8F95A6), height: 1.5),
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
