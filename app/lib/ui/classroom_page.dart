import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'widgets.dart';

class ClassroomPage extends StatefulWidget {
  final AppState state;

  const ClassroomPage({super.key, required this.state});

  @override
  State<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage> {
  late DateTime _date = DateTime.now();
  int _start = 1;
  int _end = 2;
  String? _building;
  bool _loading = false;
  String? _error;
  List<RoomSlot> _rooms = const <RoomSlot>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _query());
  }

  static const List<List<int>> _ranges = [
    [1, 2],
    [3, 4],
    [5, 6],
    [7, 8],
    [9, 10],
    [11, 12],
  ];

  Future<void> _query() async {
    final api = widget.state.api;
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rooms = await api.fetchRooms(
        date: _date,
        startSection: _start,
        endSection: _end,
        building: _building,
      );
      if (!mounted) return;
      setState(() => _rooms = rooms);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('空教室', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('日期'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < 3; i++)
                      _Chip(
                        label: i == 0 ? '今天' : (i == 1 ? '明天' : '后天'),
                        selected: _isSameDay(_date, DateTime.now().add(Duration(days: i))),
                        onTap: () => setState(
                          () => _date = DateTime.now().add(Duration(days: i)),
                        ),
                      ),
                    _Chip(
                      label: '${_date.month}/${_date.day} 选日期',
                      selected: false,
                      onTap: _pickDate,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _Label('节次'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in _ranges)
                      _Chip(
                        label: '${r[0]}-${r[1]} 节',
                        selected: _start == r[0] && _end == r[1],
                        onTap: () => setState(() {
                          _start = r[0];
                          _end = r[1];
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const _Label('教学楼'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      label: '全部',
                      selected: _building == null,
                      onTap: () => setState(() => _building = null),
                    ),
                    for (final b in widget.state.api?.buildings ?? const <String>[])
                      _Chip(
                        label: b,
                        selected: _building == b,
                        onTap: () => setState(() => _building = b),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _query,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('查询空教室'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFC0392B))),
            ),
          if (_rooms.isNotEmpty)
            SectionHeader('找到 ${_rooms.length} 间', action: '${_date.month}/${_date.day}'),
          if (_rooms.isEmpty && !_loading)
            const AppCard(
              child: EmptyView(
                icon: Icons.meeting_room_outlined,
                title: '还没有结果',
                subtitle: '选好日期和节次，点上面的按钮查询',
              ),
            )
          else
            ..._rooms.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.room,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${r.seats} 座 · 空 ${r.freeSections.length} 节',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF9AA0B4)),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 4,
                          children: [
                            for (final s in r.freeSections.take(6))
                              Container(
                                width: 18,
                                height: 18,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EDFF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$s',
                                  style: const TextStyle(
                                    fontSize: 9,
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
                )),
          const BottomGap(),
        ],
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5C6275)),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2F5BFF) : const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? const Color(0xFF2F5BFF) : const Color(0xFFEEF0F6),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF5C6275),
          ),
        ),
      ),
    );
  }
}
