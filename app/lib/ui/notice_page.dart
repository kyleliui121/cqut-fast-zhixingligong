import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../models.dart';
import 'widgets.dart';

class NoticePage extends StatelessWidget {
  final AppState state;

  const NoticePage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final notices = state.notices;
        return Scaffold(
          appBar: AppBar(
            title: const Text('通知', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          body: RefreshIndicator(
            onRefresh: () => state.refreshAll(),
            child: notices.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      EmptyView(
                        icon: Icons.campaign_outlined,
                        title: '暂无通知',
                        subtitle: '下拉刷新试试',
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: notices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _NoticeCard(notice: notices[i]),
                  ),
          ),
        );
      },
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;

  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(notice.title, style: const TextStyle(fontSize: 16, height: 1.4)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fmtDate(notice.date),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF9AA0B4)),
                ),
                const SizedBox(height: 10),
                Text(
                  notice.summary.isEmpty ? '暂无详细内容' : notice.summary,
                  style: const TextStyle(fontSize: 13.5, height: 1.6),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notice.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.45),
          ),
          if (notice.summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              notice.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A8FA3), height: 1.5),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule, size: 12, color: Color(0xFFB0B4C4)),
              const SizedBox(width: 4),
              Text(
                fmtDate(notice.date),
                style: const TextStyle(fontSize: 10.5, color: Color(0xFFB0B4C4)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
