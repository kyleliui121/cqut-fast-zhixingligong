import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../core/version.dart';
import '../models.dart';
import 'calendar_page.dart';
import 'classroom_page.dart';
import 'notice_page.dart';
import 'settings_page.dart';
import 'widgets.dart';

class MorePage extends StatelessWidget {
  final AppState state;

  const MorePage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final account = state.account;
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              const Text(
                '更多',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2F5BFF), Color(0xFF6C86FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _avatarText(account),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account?.displayName.isNotEmpty == true
                                ? account!.displayName
                                : '同学',
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            account?.username ?? '',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF9AA0B4)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      state.lastSync == null
                          ? '未同步'
                          : '${fmtShort(state.lastSync!)} ${fmtTime(state.lastSync!)}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFFA0A5B8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.65,
                children: [
                  _Entry(
                    icon: Icons.meeting_room_outlined,
                    color: const Color(0xFF0EA5A5),
                    title: '空教室',
                    subtitle: '按时间找自习室',
                    onTap: () => _push(context, ClassroomPage(state: state)),
                  ),
                  _Entry(
                    icon: Icons.calendar_month_outlined,
                    color: const Color(0xFF8B5CF6),
                    title: '校历',
                    subtitle: '第 ${state.currentWeek} 周',
                    onTap: () => _push(context, CalendarPage(state: state)),
                  ),
                  _Entry(
                    icon: Icons.campaign_outlined,
                    color: const Color(0xFFE0A106),
                    title: '通知',
                    subtitle: state.notices.isEmpty ? '暂无' : '${state.notices.length} 条',
                    onTap: () => _push(context, NoticePage(state: state)),
                  ),
                  _Entry(
                    icon: Icons.settings_outlined,
                    color: const Color(0xFF5C6275),
                    title: '设置',
                    subtitle: '账号与数据',
                    onTap: () => _push(context, SettingsPage(state: state)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF9AA0B4)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '所有课表、成绩、考试数据都缓存在本机，断网也能查看。'
                        '下拉即可刷新。',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: const Color(0xFF8A8FA3),
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  '知行闪课 v$kAppVersion',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFFB0B4C4)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _avatarText(Account? account) {
    final name = account?.displayName ?? '';
    if (name.isNotEmpty) return name.substring(0, 1);
    final id = account?.username ?? '';
    if (id.isNotEmpty) return id.substring(0, 1);
    return '?';
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _Entry extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Entry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const Spacer(),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF9AA0B4)),
          ),
        ],
      ),
    );
  }
}
