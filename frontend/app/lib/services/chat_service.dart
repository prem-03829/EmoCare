import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatMessage {
  final String role;
  final String text;
  final DateTime? createdAt;
  final String? emotion;
  final double? confidence;

  ChatMessage({
    required this.role,
    required this.text,
    this.createdAt,
    this.emotion,
    this.confidence,
  });
}

class ChatReply {
  final String reply;
  final String? emotion;
  final double? confidence;

  ChatReply({
    required this.reply,
    this.emotion,
    this.confidence,
  });
}

class ChatService {
  static const String baseUrl = "http://192.168.0.139:8000";
  static const String _guestUserId = "11111111-1111-1111-1111-111111111111";
  static String? _accessToken;
  static String? _userId;

  static void configureAuth({
    required String accessToken,
    required String userId,
  }) {
    _accessToken = accessToken;
    _userId = userId;
  }

  static void clearAuth() {
    _accessToken = null;
    _userId = null;
  }

  String get _effectiveUserId => _userId ?? _guestUserId;
  bool get _hasAuth => (_accessToken?.isNotEmpty ?? false) && (_userId?.isNotEmpty ?? false);

  Future<ChatReply> sendMessage(String message) async {
    try {
      if (!_hasAuth) {
        return ChatReply(reply: "Please login from drawer to start chatting.");
      }

      final response = await http.post(
        Uri.parse("$baseUrl/chat/chat"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_accessToken",
        },
        body: jsonEncode({
          "message": message,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return ChatReply(
          reply: data["reply"]?.toString() ?? "No reply",
          emotion: data["emotion"]?.toString(),
          confidence: _toDouble(data["confidence"]),
        );
      } else {
        return ChatReply(reply: "Server error: ${response.statusCode}");
      }
    } catch (e) {
      return ChatReply(reply: "Connection error: $e");
    }
  }

  Future<List<ChatMessage>> fetchHistory() async {
    final response =
        await http.get(Uri.parse("$baseUrl/chat/history/$_effectiveUserId"));

    if (response.statusCode != 200) {
      throw Exception("Server error: ${response.statusCode}");
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      return [];
    }

    final List<ChatMessage> history = [];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final createdAtRaw = item["created_at"]?.toString();
      final createdAt = createdAtRaw == null
          ? null
          : DateTime.tryParse(createdAtRaw.replaceFirst("Z", ""));

      final userText = item["message"]?.toString() ?? "";
      final botText = item["reply"]?.toString() ?? "";
      final emotion = item["emotion"]?.toString();
      final confidence = _toDouble(item["confidence"]);

      if (userText.isNotEmpty) {
        history.add(
          ChatMessage(role: "user", text: userText, createdAt: createdAt),
        );
      }
      if (botText.isNotEmpty) {
        history.add(
          ChatMessage(
            role: "bot",
            text: botText,
            createdAt: createdAt,
            emotion: emotion,
            confidence: confidence,
          ),
        );
      }
    }

    return history;
  }

  Future<ChatReply> sendVoiceMessage(String audioFilePath) async {
    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/voice/"),
      );
      request.fields["user_id"] = _effectiveUserId;
      request.files.add(
        await http.MultipartFile.fromPath("file", audioFilePath),
      );

      final streamed =
          await request.send().timeout(const Duration(seconds: 180));
      final bodyBytes = await streamed.stream.toBytes().timeout(
            const Duration(seconds: 180),
          );
      final body = utf8.decode(bodyBytes);

      if (streamed.statusCode == 200) {
        final data = jsonDecode(body);
        return ChatReply(
          reply: data["reply"]?.toString() ?? "No reply",
          emotion: data["emotion"]?.toString(),
          confidence: _toDouble(data["confidence"]),
        );
      }

      return ChatReply(
        reply: "Server error: ${streamed.statusCode} ${body.isNotEmpty ? body : ""}",
      );
    } catch (e) {
      return ChatReply(reply: "Connection error: $e");
    }
  }

  Future<Map<String, dynamic>> fetchDailyMood() async {
    final response = await http.get(Uri.parse("$baseUrl/chat/mood/$_effectiveUserId"));
    if (response.statusCode != 200) {
      throw Exception("Server error: ${response.statusCode}");
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<List<Map<String, dynamic>>> fetchEmotionTimeline() async {
    final response = await http.get(Uri.parse("$baseUrl/chat/timeline/$_effectiveUserId"));
    if (response.statusCode != 200) {
      throw Exception("Server error: ${response.statusCode}");
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> fetchWeeklyInsight() async {
    final response =
        await http.get(Uri.parse("$baseUrl/chat/weekly-insight/$_effectiveUserId"));
    if (response.statusCode != 200) {
      throw Exception("Server error: ${response.statusCode}");
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
