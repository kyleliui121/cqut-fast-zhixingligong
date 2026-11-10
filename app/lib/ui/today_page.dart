import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../models.dart';
import 'widgets.dart';

class TodayPage extends StatelessWidget {
  final AppState state;

  const TodayPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final now = DateTime.now();
        final courses = state.todayCourses;
        final next = state.nextCourse;
        final exams = state.upcomingExams.take(2).toList();

        return RefreshIndicator(
          onRefresh: () => state.refreshAll(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            children: [
              _Header(state: state, now: now),
              const SizedBox(height: 16),
              _NextCourseCard(
                state: state,
                course: next,
                now: now,
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: state.error!, onRetry: () => state.refreshAll()),
              ],
              if (state.newGradeCount > 0) ...[
                const SizedBox(height: 12),
                _NewGradeBanner(count: state.newGradeCount),
              ],
              const SizedBox(height: 22),
              SectionHeader('今日课程', action: courses.isEmpty ? null : '${courses.length} 节'),
              if (courses.isEmpty)
                const AppCard(
                  child: EmptyView(
                    icon: Icons.local_cafe_outlined,
                    title: '今天没有课',
                    subtitle: '去图书馆坐坐，或者补个觉也行',
                  ),
                )
              else
                ...courses.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CourseTile(course: c, now: now),
                    )),
              if (exams.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionHeader('近期考试'),
                ...exams.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ExamRow(exam: e, now: now),
                    )),
              ],
              const BottomGap(),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final AppState state;
  final DateTime now;

  const _Header({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${now.month}月${now.day}日',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.15),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '星期${weekdayCn(now.weekday)}',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF7A8099)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EDFF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '第 ${state.currentWeek} 周',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2F5BFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _IconAction(
          icon: Icons.refresh_rounded,
          busy: state.busy,
          onTap: () => state.refreshAll(),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;

  const _IconAction({required this.icon, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEFF0F6)),
          ),
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 20, color: const Color(0xFF3B4256)),
        ),
      ),
    );
  }
}

class _NewGradeBanner extends StatelessWidget {
  final int count;

  const _NewGradeBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE7B8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 16, color: Color(0xFFB4740B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '有 $count 门新成绩可以看了',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A5B00)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEEEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF6D2D2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFC0392B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9B2C2C), height: 1.4),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('重试', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _NextCourseCard extends StatelessWidget {
  final AppState state;
  final Course? course;
  final DateTime now;

  const _NextCourseCard({required this.state, required this.course, required this.now});

  @override
  Widget build(BuildContext context) {
    final c = course;
    if (c == null) {
      final tomorrow = _firstCourseTomorrow(state);
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C88A8), Color(0xFF9AA5BE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.nightlight_round, size: 14, color: Colors.white70),
                SizedBox(width: 6),
                Text('今天的课结束了', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tomorrow == null ? '好好休息' : '明天 08:20  ${tomorrow.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              tomorrow == null ? '明天也没有课' : '${tomorrow.location}  ·  ${tomorrow.teacher}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    final start = _timeAt(now, sectionAt(c.startSection)!.start);
    final end = _timeAt(now, sectionAt(c.endSection)!.end);
    final ongoing = !now.isBefore(start) && now.isBefore(end);
    final countdown = humanCountdown(ongoing ? end : start, now: now);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2F5BFF), Color(0xFF6C86FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F5BFF).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ongoing ? Icons.play_circle_outline : Icons.schedule_rounded,
                size: 15,
                color: Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                ongoing ? '正在上课' : '下一节',
                style: const TextStyle(fontSize: 12, color: Colors.white70, letterSpacing: 0.5),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  countdown,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            c.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(c.location, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
              const SizedBox(width: 14),
              const Icon(Icons.access_time, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                '${sectionAt(c.startSection)!.start}-${sectionAt(c.endSection)!.end}',
                style: const TextStyle(fontSize: 12.5, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Course? _firstCourseTomorrow(AppState state) {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final week = weekIndex(tomorrow, state.termStart);
  final list = state.coursesOf(week, tomorrow.weekday);
  return list.isEmpty ? null : list.first;
}

class _CourseTile extends StatelessWidget {
  final Course course;
  final DateTime now;

  const _CourseTile({required this.course, required this.now});

  @override
  Widget build(BuildContext context) {
    final color = courseColor(course.name);
    final status = _statusOf(course, now);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => showCourseDetail(context, course),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sectionAt(course.startSection)!.start,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  sectionAt(course.endSection)!.end,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF9AA0B4)),
                ),
              ],
            ),
          ),
          Container(
            width: 3.5,
            height: 40,
            decoration: BoxDecoration(
              color: status == _Status.done ? color.withValues(alpha: 0.35) : color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: status == _Status.done ? const Color(0xFF8A8FA3) : const Color(0xFF20242F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${course.location}  ·  ${course.teacher}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A8FA3)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pill(status.label, color: status.color),
        ],
      ),
    );
  }
}

enum _Status {
  done('已结束', Color(0xFF9AA0B4)),
  ongoing('进行中', Color(0xFF12A05C)),
  upcoming('未开始', Color(0xFF2F5BFF));

  const _Status(this.label, this.color);

  final String label;
  final Color color;
}

_Status _statusOf(Course c, DateTime now) {
  final start = _timeAt(now, sectionAt(c.startSection)!.start);
  final end = _timeAt(now, sectionAt(c.endSection)!.end);
  if (now.isAfter(end)) return _Status.done;
  if (!now.isBefore(start)) return _Status.ongoing;
  return _Status.upcoming;
}

DateTime _timeAt(DateTime day, String hhmm) {
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(hhmm.substring(0, 2)),
    int.parse(hhmm.substring(3, 5)),
  );
}

class _ExamRow extends StatelessWidget {
  final Exam exam;
  final DateTime now;

  const _ExamRow({required this.exam, required this.now});

  @override
  Widget build(BuildContext context) {
    final days = (exam.start.difference(now).inHours / 24).ceil();
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => showExamDetail(context, exam),
      child: Row(
        children: [
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${exam.start.month}月',
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF7A8099)),
                ),
                Text(
                  '${exam.start.day}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${fmtTime(exam.start)}  ${exam.location}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A8FA3)),
                ),
              ],
            ),
          ),
          Pill(days <= 0 ? '今天' : '$days 天后', color: const Color(0xFFE0651A)),
        ],
      ),
    );
  }
}

void showCourseDetail(BuildContext context, Course course) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) {
      final color = courseColor(course.name);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('课程详情', style: TextStyle(fontSize: 12, color: Color(0xFF8A8FA3))),
                ],
              ),
              const SizedBox(height: 10),
              Text(course.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _DetailRow(icon: Icons.person_outline, label: '教师', value: course.teacher),
              _DetailRow(icon: Icons.place_outlined, label: '地点', value: course.location),
              _DetailRow(
                icon: Icons.access_time,
                label: '时间',
                value: '周${weekdayCn(course.weekday)} ${course.sectionLabel} '
                    '(${sectionRangeLabel(course.startSection, course.endSection)})',
              ),
              _DetailRow(icon: Icons.date_range_outlined, label: '周次', value: course.weeksLabel),
            ],
          ),
        ),
      );
    },
  );
}

void showExamDetail(BuildContext context, Exam exam) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('考试安排', style: TextStyle(fontSize: 12, color: Color(0xFF8A8FA3))),
            const SizedBox(height: 10),
            Text(exam.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.event_outlined,
              label: '日期',
              value: '${exam.start.year}年${exam.start.month}月${exam.start.day}日 '
                  '星期${weekdayCn(exam.start.weekday)}',
            ),
            _DetailRow(
              icon: Icons.access_time,
              label: '时间',
              value: exam.end == null
                  ? fmtTime(exam.start)
                  : '${fmtTime(exam.start)} - ${fmtTime(exam.end!)}',
            ),
            _DetailRow(icon: Icons.place_outlined, label: '考场', value: exam.location),
            if (exam.seat.isNotEmpty)
              _DetailRow(icon: Icons.event_seat_outlined, label: '座位', value: exam.seat),
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9AA0B4)),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8A8FA3))),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}
