import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../models.dart';
import 'today_page.dart';
import 'widgets.dart';

class TimetablePage extends StatefulWidget {
  final AppState state;

  const TimetablePage({super.key, required this.state});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late int _week;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _week = widget.state.currentWeek;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final total = state.term?.totalWeeks ?? 20;
        final week = _week.clamp(1, total);
        final today = DateTime.now();
        final days = List<DateTime>.generate(
          7,
          (i) => dateOfWeekday(state.termStart, week, i + 1),
        );

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Text(
                      '课表',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.term?.name ?? '',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF9AA0B4)),
                    ),
                    const Spacer(),
                    if (week != state.currentWeek)
                      TextButton(
                        onPressed: () => setState(() => _week = state.currentWeek),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('回到本周', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
              _WeekBar(
                week: week,
                total: total,
                onChange: (w) => setState(() => _week = w),
              ),
              _DayHeader(days: days, today: today),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _TimetableGrid(
                    week: week,
                    days: days,
                    courses: [
                      for (var w = 1; w <= 7; w++) ...state.coursesOf(week, w),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekBar extends StatelessWidget {
  final int week;
  final int total;
  final ValueChanged<int> onChange;

  const _WeekBar({required this.week, required this.total, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          IconButton(
            onPressed: week > 1 ? () => onChange(week - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EDFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '第 $week 周',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F5BFF),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: week < total ? () => onChange(week + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final List<DateTime> days;
  final DateTime today;

  const _DayHeader({required this.days, required this.today});

  @override
  Widget build(BuildContext context) {
    const timeCol = 30.0;
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 6),
      child: Row(
        children: [
          const SizedBox(width: timeCol),
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _isSameDay(days[i], today)
                  ? Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F5BFF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '周${kWeekdayShort[i]}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${days[i].month}/${days[i].day}',
                            style: const TextStyle(fontSize: 9, color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Text(
                            '周${kWeekdayShort[i]}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5C6275),
                            ),
                          ),
                          Text(
                            '${days[i].month}/${days[i].day}',
                            style: const TextStyle(fontSize: 9, color: Color(0xFFA0A5B8)),
                          ),
                        ],
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _TimetableGrid extends StatelessWidget {
  final int week;
  final List<DateTime> days;
  final List<Course> courses;

  const _TimetableGrid({required this.week, required this.days, required this.courses});

  static const double rowHeight = 58;
  static const double timeCol = 30;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 16;
        final dayWidth = (width - timeCol) / 7;
        final height = rowHeight * kSections.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                // 背景横线
                for (var i = 0; i < kSections.length; i++)
                  Positioned(
                    top: i * rowHeight,
                    left: 0,
                    right: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: timeCol - 4,
                          child: Text(
                            kSections[i].start,
                            style: const TextStyle(fontSize: 8.5, color: Color(0xFFA8ADBF)),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(top: 5),
                            height: 1,
                            color: const Color(0xFFEDEFF5),
                          ),
                        ),
                      ],
                    ),
                  ),
                // 竖向分隔
                for (var d = 1; d < 7; d++)
                  Positioned(
                    left: timeCol + d * dayWidth,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: const Color(0xFFF3F4F8)),
                  ),
                // 课程块
                ...courses.where((c) => c.activeIn(week)).map((c) {
                  final left = timeCol + (c.weekday - 1) * dayWidth + 1;
                  final top = (c.startSection - 1) * rowHeight + 2;
                  final w = dayWidth - 2;
                  final h = c.sectionCount * rowHeight - 4;
                  return Positioned(
                    left: left,
                    top: top,
                    width: w,
                    height: h,
                    child: _CourseBlock(course: c),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CourseBlock extends StatelessWidget {
  final Course course;

  const _CourseBlock({required this.course});

  @override
  Widget build(BuildContext context) {
    final color = courseColor(course.name);
    return GestureDetector(
      onTap: () => showCourseDetail(context, course),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: color.withValues(alpha: 0.13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 5, 3, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: Color.lerp(color, Colors.black, 0.35),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (course.location.isNotEmpty)
                        Text(
                          course.location,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 8.5,
                            height: 1.2,
                            color: color.withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
