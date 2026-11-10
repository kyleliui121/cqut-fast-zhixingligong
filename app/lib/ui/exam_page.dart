import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../models.dart';
import 'today_page.dart';
import 'widgets.dart';

class ExamPage extends StatelessWidget {
  final AppState state;

  const ExamPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final now = DateTime.now();
        final upcoming = state.upcomingExams;
        final past = state.exams
            .where((e) => e.start.isBefore(now.subtract(const Duration(hours: 3))))
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));

        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => state.refreshAll(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Row(
                  children: [
                    const Text(
                      '考试',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      upcoming.isEmpty ? '' : '${upcoming.length} 场待考',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF9AA0B4)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (upcoming.isEmpty)
                  const AppCard(
                    child: EmptyView(
                      icon: Icons.sentiment_satisfied_alt_outlined,
                      title: '暂无考试安排',
                      subtitle: '教务处排考后，这里会自动出现',
                    ),
                  )
                else
                  ...upcoming.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExamCard(exam: e, now: now, highlighted: e == upcoming.first),
                      )),
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const SectionHeader('已结束'),
                  ...past.take(4).map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PastExamRow(exam: e),
                      )),
                ],
                const BottomGap(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExamCard extends StatelessWidget {
  final Exam exam;
  final DateTime now;
  final bool highlighted;

  const _ExamCard({required this.exam, required this.now, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final diff = exam.start.difference(now);
    final days = (diff.inHours / 24).ceil();
    final hours = diff.inHours;
    final label = diff.isNegative
        ? '进行中'
        : days > 0
            ? '$days 天后'
            : hours > 0
                ? '$hours 小时后'
                : '即将开始';

    return AppCard(
      onTap: () => showExamDetail(context, exam),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 56,
                decoration: BoxDecoration(
                  gradient: highlighted
                      ? const LinearGradient(
                          colors: [Color(0xFF2F5BFF), Color(0xFF6C86FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: highlighted ? null : const Color(0xFFF3F5FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${exam.start.month}月',
                      style: TextStyle(
                        fontSize: 10,
                        color: highlighted ? Colors.white70 : const Color(0xFF7A8099),
                      ),
                    ),
                    Text(
                      '${exam.start.day}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        color: highlighted ? Colors.white : const Color(0xFF20242F),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${fmtTime(exam.start)}${exam.end == null ? '' : ' - ${fmtTime(exam.end!)}'}  '
                      '·  周${weekdayCn(exam.start.weekday)}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A8FA3)),
                    ),
                  ],
                ),
              ),
              Pill(label, color: highlighted ? const Color(0xFF2F5BFF) : const Color(0xFFE0651A)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 14, color: Color(0xFF9AA0B4)),
              const SizedBox(width: 4),
              Text(exam.location, style: const TextStyle(fontSize: 12, color: Color(0xFF5C6275))),
              if (exam.seat.isNotEmpty) ...[
                const SizedBox(width: 16),
                const Icon(Icons.event_seat_outlined, size: 14, color: Color(0xFF9AA0B4)),
                const SizedBox(width: 4),
                Text('座位 ${exam.seat}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5C6275))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PastExamRow extends StatelessWidget {
  final Exam exam;

  const _PastExamRow({required this.exam});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => showExamDetail(context, exam),
      child: Row(
        children: [
          Text(
            '${exam.start.month}/${exam.start.day}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9AA0B4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              exam.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B7280)),
            ),
          ),
          Text(
            exam.location,
            style: const TextStyle(fontSize: 11, color: Color(0xFFA0A5B8)),
          ),
        ],
      ),
    );
  }
}
