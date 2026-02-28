import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/chat_service.dart';

class MoodInsightsScreen extends StatefulWidget {
  const MoodInsightsScreen({super.key});

  @override
  State<MoodInsightsScreen> createState() => _MoodInsightsScreenState();
}

class _MoodInsightsScreenState extends State<MoodInsightsScreen> {
  final ChatService _chatService = ChatService();
  late Future<_MoodInsightsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MoodInsightsData> _load() async {
    final results = await Future.wait([
      _chatService.fetchDailyMood(),
      _chatService.fetchEmotionTimeline(),
      _chatService.fetchWeeklyInsight(),
    ]);

    return _MoodInsightsData(
      dailyMood: results[0] as Map<String, dynamic>,
      timeline: results[1] as List<Map<String, dynamic>>,
      weeklyInsight: results[2] as Map<String, dynamic>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1428),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1428),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text(
          "Mood Insights",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: FutureBuilder<_MoodInsightsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Failed to load insights: ${snapshot.error}",
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            );
          }

          final data = snapshot.data!;
          final daily = data.dailyMood;
          final timeline = data.timeline;
          final weekly = data.weeklyInsight;
          final weeklySummary = weekly["weekly_insight"]?.toString();
          final weeklyCounts = weekly["weekly_emotion_counts"];
          final chartData = _toChartData(weeklyCounts);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card(
                title: "Today's Mood",
                child: daily.containsKey("message")
                    ? Text(
                        daily["message"].toString(),
                        style: const TextStyle(color: Colors.white70),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kv("Dominant", daily["dominant_emotion"]),
                          _kv("Confidence", daily["average_confidence"]),
                          _kv("Messages", daily["total_messages"]),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              _card(
                title: "Emotion Timeline",
                child: timeline.isEmpty
                    ? const Text(
                        "No timeline data yet.",
                        style: TextStyle(color: Colors.white70),
                      )
                    : Column(
                        children: timeline.map((row) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF7FD1FF),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    row["dominant_emotion"]?.toString() ?? "-",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                Text(
                                  row["date"]?.toString() ?? "-",
                                  style: const TextStyle(color: Colors.white60),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 14),
              _card(
                title: "Weekly Emotion Split",
                child: chartData.isEmpty
                    ? const Text(
                        "No weekly emotion chart data yet.",
                        style: TextStyle(color: Colors.white70),
                      )
                    : _EmotionPieChart(data: chartData),
              ),
              const SizedBox(height: 14),
              _card(
                title: "Weekly Insight",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (weekly.containsKey("message"))
                      Text(
                        weekly["message"].toString(),
                        style: const TextStyle(color: Colors.white70),
                      )
                    else ...[
                      if (weeklyCounts is Map)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: weeklyCounts.entries.map((e) {
                            return _chip("${e.key}: ${e.value}");
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      if (weeklySummary != null)
                        Text(
                          weeklySummary,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF5A7FFF).withOpacity(0.12),
            const Color(0xFF4FA3A5).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white30, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A7FFF).withOpacity(0.16),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withOpacity(0.2), height: 1),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _kv(String k, dynamic v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        "$k: ${v ?? '-'}",
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF5A7FFF).withOpacity(0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  List<_EmotionSlice> _toChartData(dynamic weeklyCounts) {
    if (weeklyCounts is! Map) return [];

    final entries = <MapEntry<String, int>>[];
    weeklyCounts.forEach((key, value) {
      final emotion = key.toString().trim();
      final count = int.tryParse(value.toString()) ?? 0;
      if (emotion.isNotEmpty && count > 0) {
        entries.add(MapEntry(emotion, count));
      }
    });

    if (entries.isEmpty) return [];

    const palette = <Color>[
      Color(0xFF5A7FFF),
      Color(0xFF4FA3A5),
      Color(0xFF7BD389),
      Color(0xFFFFB26B),
      Color(0xFFF77FBE),
      Color(0xFFB892FF),
      Color(0xFF7FD1FF),
    ];

    return List<_EmotionSlice>.generate(entries.length, (i) {
      final entry = entries[i];
      return _EmotionSlice(
        emotion: entry.key,
        count: entry.value,
        color: palette[i % palette.length],
      );
    });
  }
}

class _MoodInsightsData {
  final Map<String, dynamic> dailyMood;
  final List<Map<String, dynamic>> timeline;
  final Map<String, dynamic> weeklyInsight;

  _MoodInsightsData({
    required this.dailyMood,
    required this.timeline,
    required this.weeklyInsight,
  });
}

class _EmotionSlice {
  final String emotion;
  final int count;
  final Color color;

  const _EmotionSlice({
    required this.emotion,
    required this.count,
    required this.color,
  });
}

class _EmotionPieChart extends StatelessWidget {
  final List<_EmotionSlice> data;

  const _EmotionPieChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.fold<int>(0, (sum, item) => sum + item.count);

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: CustomPaint(
                painter: _PieChartPainter(data),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Total",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        "$total",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: data.map((slice) {
            final pct = total == 0 ? 0 : (slice.count * 100 / total);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: slice.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: slice.color.withOpacity(0.7)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: slice.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${slice.emotion}: ${pct.toStringAsFixed(0)}%",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<_EmotionSlice> data;

  _PieChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold<int>(0, (sum, item) => sum + item.count);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()..style = PaintingStyle.fill;

    double start = -math.pi / 2;
    for (final slice in data) {
      final sweep = (slice.count / total) * (2 * math.pi);
      paint.color = slice.color;
      canvas.drawArc(rect, start, sweep, true, paint);
      start += sweep;
    }

    // donut center
    final holePaint = Paint()..color = const Color(0xFF0A1428);
    canvas.drawCircle(center, radius * 0.52, holePaint);

    // ring stroke for better separation from background
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withOpacity(0.26);
    canvas.drawCircle(center, radius - 0.75, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) => oldDelegate.data != data;
}

