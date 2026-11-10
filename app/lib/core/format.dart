/// 时间与格式化工具。不依赖 intl，避免版本冲突。
String pad2(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

String fmtShort(DateTime d) => '${d.month}月${d.day}日';

String fmtTime(DateTime d) => '${pad2(d.hour)}:${pad2(d.minute)}';

String fmtDateTime(DateTime d) => '${fmtShort(d)} ${fmtTime(d)}';

String weekdayCn(int weekday) {
  const names = ['一', '二', '三', '四', '五', '六', '日'];
  final i = (weekday - 1).clamp(0, 6);
  return names[i];
}

String todayLabel(DateTime d) => '${d.month}月${d.day}日 星期${weekdayCn(d.weekday)}';

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

int daysBetween(DateTime a, DateTime b) =>
    startOfDay(b).difference(startOfDay(a)).inDays;

/// 学期第几周（1 起），早于开学返回 1。
int weekIndex(DateTime date, DateTime termStart) {
  final diff = daysBetween(termStart, date);
  if (diff < 0) return 1;
  return diff ~/ 7 + 1;
}

/// 第 [week] 周星期 [weekday] 的日期。
DateTime dateOfWeekday(DateTime termStart, int week, int weekday) =>
    startOfDay(termStart).add(Duration(days: (week - 1) * 7 + (weekday - 1)));

class SectionTime {
  final int index;
  final String start;
  final String end;
  const SectionTime(this.index, this.start, this.end);

  String get label => '第$index节';
  String get range => '$start-$end';
}

/// 默认作息，可在设置里改（后续版本）。
const List<SectionTime> kSections = [
  SectionTime(1, '08:20', '09:05'),
  SectionTime(2, '09:10', '09:55'),
  SectionTime(3, '10:10', '10:55'),
  SectionTime(4, '11:00', '11:45'),
  SectionTime(5, '14:00', '14:45'),
  SectionTime(6, '14:50', '15:35'),
  SectionTime(7, '15:50', '16:35'),
  SectionTime(8, '16:40', '17:25'),
  SectionTime(9, '19:00', '19:45'),
  SectionTime(10, '19:50', '20:35'),
  SectionTime(11, '20:40', '21:25'),
  SectionTime(12, '21:30', '22:15'),
];

SectionTime? sectionAt(int index) {
  if (index < 1 || index > kSections.length) return null;
  return kSections[index - 1];
}

String sectionRangeLabel(int start, int end) {
  final a = sectionAt(start);
  final b = sectionAt(end);
  if (a == null || b == null) return '第$start-$end节';
  return '${a.start}-${b.end}';
}

/// 距离某个时间点的中文描述。
String humanCountdown(DateTime target, {DateTime? now}) {
  final base = now ?? DateTime.now();
  final diff = target.difference(base);
  if (diff.isNegative) {
    final past = -diff;
    if (past.inMinutes < 60) return '${past.inMinutes} 分钟前';
    if (past.inHours < 24) return '${past.inHours} 小时前';
    return '${past.inDays} 天前';
  }
  if (diff.inMinutes < 1) return '即将开始';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟后';
  if (diff.inHours < 24) {
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return m == 0 ? '$h 小时后' : '$h 小时 $m 分后';
  }
  return '${diff.inDays} 天后';
}

/// 星期几的中文短名，用于表头。
const List<String> kWeekdayShort = ['一', '二', '三', '四', '五', '六', '日'];
