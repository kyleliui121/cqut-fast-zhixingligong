import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/format.dart';
import 'widgets.dart';

class CalendarPage extends StatelessWidget {
  final AppState state;

  const CalendarPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final term = state.term;
        final total = term?.totalWeeks ?? 20;
        final current = state.currentWeek;

        return Scaffold(
          appBar: AppBar(
            title: const Text('校历', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF20325C), Color(0xFF33477A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      term?.name ?? '当前学期',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _TermStat(label: '开学', value: fmtDate(state.termStart)),
                        _TermStat(label: '当前', value: '第 $current 周'),
                        _TermStat(label: '总周数', value: '$total 周'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionHeader('每周日期'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    for (var w = 1; w <= total; w++) ...[
                      _WeekRow(
                        week: w,
                        start: dateOfWeekday(state.termStart, w, 1),
                        current: w == current,
                      ),
                      if (w != total)
                        const Divider(height: 1, color: Color(0xFFF2F3F8)),
                    ],
                  ],
                ),
              ),
              const BottomGap(),
            ],
          ),
        );
      },
    );
  }
}

class _TermStat extends StatelessWidget {
  final String label;
  final String value;

  const _TermStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final int week;
  final DateTime start;
  final bool current;

  const _WeekRow({required this.week, required this.start, required this.current});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: current ? const Color(0xFF2F5BFF) : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '第$week周',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: current ? Colors.white : const Color(0xFF5C6275),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '${start.month}月${start.day}日 - '
              '${start.add(const Duration(days: 6)).month}月'
              '${start.add(const Duration(days: 6)).day}日',
              style: TextStyle(
                fontSize: 12.5,
                color: current ? const Color(0xFF20242F) : const Color(0xFF7A8099),
                fontWeight: current ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (current)
            const Pill('本周', color: Color(0xFF2F5BFF)),
        ],
      ),
    );
  }
}
