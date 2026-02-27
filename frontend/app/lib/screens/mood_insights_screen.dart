import 'package:flutter/material.dart';
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
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              row["dominant_emotion"]?.toString() ?? "-",
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: Text(
                              row["date"]?.toString() ?? "-",
                              style: const TextStyle(color: Colors.white60),
                            ),
                          );
                        }).toList(),
                      ),
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
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
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
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
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

