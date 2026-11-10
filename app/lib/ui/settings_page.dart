import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../core/version.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  final AppState state;

  const SettingsPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final account = state.account;
        return Scaffold(
          appBar: AppBar(
            title: const Text('设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              const SectionHeader('账号'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Row(label: '学号', value: account?.username ?? '-'),
                    const Divider(),
                    _Row(label: '数据源', value: state.api?.displayName ?? '未连接'),
                    const Divider(),
                    _Row(
                      label: '上次同步',
                      value: state.lastSync == null
                          ? '从未同步'
                          : fmtDateTime(state.lastSync!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader('同步与学期'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _TapRow(
                      icon: Icons.sync_rounded,
                      label: '立即同步',
                      trailing: state.busy ? '同步中…' : '',
                      onTap: state.busy ? null : () => state.refreshAll(),
                    ),
                    const Divider(),
                    _TapRow(
                      icon: Icons.flag_outlined,
                      label: '开学第一周星期一',
                      trailing: fmtDate(state.termStart),
                      onTap: () => _pickStartDate(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader('数据'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _TapRow(
                      icon: Icons.cleaning_services_outlined,
                      label: '清除本地缓存',
                      trailing: '',
                      onTap: () => _confirmClear(context),
                    ),
                    const Divider(),
                    _TapRow(
                      icon: Icons.logout_rounded,
                      label: '退出登录',
                      trailing: '',
                      danger: true,
                      onTap: () => _confirmLogout(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  '知行闪课 v$kAppVersion · 数据仅存本机',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFFB0B4C4)),
                ),
              ),
              const BottomGap(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: state.termStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: '选择第 1 周星期一',
    );
    if (picked != null) {
      await state.updateTermStart(picked);
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除本地缓存？'),
        content: const Text('课表、成绩、考试和通知的本地副本会被删除，账号会保留。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('清除')),
        ],
      ),
    );
    if (ok == true) {
      await state.clearCache();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本地缓存已清除')),
        );
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录？'),
        content: const Text('本地缓存的课表和成绩会保留，重新登录即可继续使用。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('退出')),
        ],
      ),
    );
    if (ok == true) {
      await state.logout();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5, color: Color(0xFF5C6275))),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF9AA0B4))),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String trailing;
  final VoidCallback? onTap;
  final bool danger;

  const _TapRow({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFD64545) : const Color(0xFF20242F);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: danger ? color : const Color(0xFF7A8099)),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 13.5, color: color)),
            const Spacer(),
            Text(trailing, style: const TextStyle(fontSize: 12, color: Color(0xFF9AA0B4))),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFC7CAD6)),
          ],
        ),
      ),
    );
  }
}
