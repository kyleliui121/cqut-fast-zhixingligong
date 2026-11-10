import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'widgets.dart';

class GradePage extends StatefulWidget {
  final AppState state;

  const GradePage({super.key, required this.state});

  @override
  State<GradePage> createState() => _GradePageState();
}

class _GradePageState extends State<GradePage> {
  String? _term;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final terms = state.grades.map((g) => g.term).where((t) => t.isNotEmpty).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
        final filtered = _term == null
            ? state.grades
            : state.grades.where((g) => g.term == _term).toList();

        final credits = filtered.fold<double>(0, (sum, g) => sum + g.credit);
        final gpaCredits = filtered.where((g) => g.gpa != null).fold<double>(0, (s, g) => s + g.credit);
        final gpaSum = filtered.where((g) => g.gpa != null).fold<double>(0, (s, g) => s + g.gpa! * g.credit);
        final gpa = gpaCredits > 0 ? gpaSum / gpaCredits : null;

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
                      '成绩',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    if (state.newGradeCount > 0)
                      Pill('${state.newGradeCount} 门新成绩', color: const Color(0xFFE0651A)),
                  ],
                ),
                const SizedBox(height: 16),
                _SummaryCard(
                  gpa: gpa,
                  credits: credits,
                  count: filtered.length,
                ),
                const SizedBox(height: 14),
                if (terms.length > 1)
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _TermChip(
                          label: '全部',
                          selected: _term == null,
                          onTap: () => setState(() => _term = null),
                        ),
                        for (final t in terms)
                          _TermChip(
                            label: t,
                            selected: _term == t,
                            onTap: () => setState(() => _term = t),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const AppCard(
                    child: EmptyView(
                      icon: Icons.insert_chart_outlined,
                      title: '还没有成绩',
                      subtitle: '成绩发布后会自动同步到这里',
                    ),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < filtered.length; i++) ...[
                          _GradeRow(grade: filtered[i]),
                          if (i != filtered.length - 1)
                            const Divider(height: 1, color: Color(0xFFF2F3F8)),
                        ],
                      ],
                    ),
                  ),
                const BottomGap(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TermChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TermChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2F5BFF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF2F5BFF) : const Color(0xFFE9EBF3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF5C6275),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double? gpa;
  final double credits;
  final int count;

  const _SummaryCard({required this.gpa, required this.credits, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF20325C), Color(0xFF33477A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: '平均绩点',
              value: gpa == null ? '--' : gpa!.toStringAsFixed(2),
            ),
          ),
          Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.14)),
          Expanded(
            child: _Stat(
              label: '已修学分',
              value: credits == credits.roundToDouble()
                  ? credits.toStringAsFixed(0)
                  : credits.toStringAsFixed(1),
            ),
          ),
          Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.14)),
          Expanded(child: _Stat(label: '课程数', value: '$count')),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: Colors.white60),
        ),
      ],
    );
  }
}

class _GradeRow extends StatelessWidget {
  final Grade grade;

  const _GradeRow({required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(grade);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        grade.courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (grade.isNew) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0651A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '新',
                          style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (grade.term.isNotEmpty) grade.term,
                    if (grade.type.isNotEmpty) grade.type,
                    '${grade.credit.toStringAsFixed(grade.credit == grade.credit.roundToDouble() ? 0 : 1)} 学分',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF9AA0B4)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                grade.score,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                ),
              ),
              if (grade.gpa != null)
                Text(
                  '${grade.gpa!.toStringAsFixed(1)} 绩点',
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF9AA0B4)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _scoreColor(Grade g) {
  final v = g.scoreValue;
  if (v == null) {
    if (g.score.contains('优秀')) return const Color(0xFF12A05C);
    if (g.score.contains('良好')) return const Color(0xFF2F5BFF);
    if (g.score.contains('及格') || g.score.contains('合格')) return const Color(0xFFE0651A);
    if (g.score.contains('不及格') || g.score.contains('不合格')) return const Color(0xFFD64545);
    return const Color(0xFF5C6275);
  }
  if (v >= 90) return const Color(0xFF12A05C);
  if (v >= 80) return const Color(0xFF2F5BFF);
  if (v >= 70) return const Color(0xFFB4740B);
  if (v >= 60) return const Color(0xFFE0651A);
  return const Color(0xFFD64545);
}
