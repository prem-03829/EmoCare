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
  static const String _envBaseUrl =
      String.fromEnvironment("API_BASE_URL", defaultValue: "");
  static const String _envApiUserId =
      String.fromEnvironment("API_USER_ID", defaultValue: "prem");
  static String get baseUrl =>
      _envBaseUrl.isNotEmpty ? _envBaseUrl : "http://10.0.2.2:8000";
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

  String get _effectiveUserId {
    if (_envApiUserId.isNotEmpty) return _envApiUserId;
    if (_userId != null && _userId!.isNotEmpty) return _userId!;
    return "prem";
  }
  bool get _hasAuth => (_accessToken?.isNotEmpty ?? false) && (_userId?.isNotEmpty ?? false);

  Future<ChatReply> sendMessage(String message) async {
    try {
      final headers = <String, String>{
        "Content-Type": "application/json",
      };
      if (_hasAuth) {
        headers["Authorization"] = "Bearer $_accessToken";
      }

      http.Response response = await http.post(
        Uri.parse("$baseUrl/chat"),
        headers: headers,
        body: jsonEncode({
          "message": message,
          "user_id": _effectiveUserId,
        }),
      );
      if (response.statusCode == 404) {
        // Backward compatibility with older backend path.
        response = await http.post(
          Uri.parse("$baseUrl/chat/send"),
          headers: headers,
          body: jsonEncode({
            "message": message,
            "user_id": _effectiveUserId,
          }),
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final replyText = data["reply"]?.toString().trim();
        return ChatReply(
          reply: (replyText == null || replyText.isEmpty)
              ? "I'm here with you. Could you tell me a little more?"
              : replyText,
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
    final headers = <String, String>{};
    if (_hasAuth) {
      headers["Authorization"] = "Bearer $_accessToken";
    }
    final response = await http.get(
      Uri.parse("$baseUrl/chat/history?user_id=$_effectiveUserId"),
      headers: headers,
    );

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

      final sender = item["sender"]?.toString();
      final content = item["content"]?.toString() ?? "";
      final userText = sender == "user"
          ? content
          : (item["message"]?.toString() ?? "");
      final botText = sender == "bot"
          ? content
          : (item["reply"]?.toString() ?? "");
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
      Future<http.StreamedResponse> sendTo(String path) async {
        final request = http.MultipartRequest("POST", Uri.parse("$baseUrl$path"));
        request.fields["user_id"] = _effectiveUserId;
        if (_hasAuth) {
          request.headers["Authorization"] = "Bearer $_accessToken";
        }
        request.files.add(await http.MultipartFile.fromPath("file", audioFilePath));
        return request.send().timeout(const Duration(seconds: 180));
      }

      // Current backend mounts voice router at root.
      var streamed = await sendTo("/");
      if (streamed.statusCode == 404) {
        // Backward compatibility with older backend path.
        streamed = await sendTo("/voice/");
      }

      final bodyBytes = await streamed.stream.toBytes().timeout(const Duration(seconds: 180));
      final body = utf8.decode(bodyBytes);

      if (streamed.statusCode == 200) {
        final data = jsonDecode(body);
        final replyText = data["reply"]?.toString().trim();
        return ChatReply(
          reply: (replyText == null || replyText.isEmpty)
              ? "I'm here with you. Could you tell me a little more?"
              : replyText,
          emotion: data["emotion"]?.toString(),
          confidence: _toDouble(data["confidence"]),
        );
      }

      return ChatReply(reply: "Server error: ${streamed.statusCode} ${body.isNotEmpty ? body : ""}");
    } catch (e) {
      return ChatReply(reply: "Connection error: $e");
    }
  }

  Future<Map<String, dynamic>> fetchDailyMood() async {
    final headers = <String, String>{};
    if (_hasAuth) {
      headers["Authorization"] = "Bearer $_accessToken";
    }
    final response = await http.get(
      Uri.parse("$baseUrl/chat/mood/today?user_id=$_effectiveUserId"),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception("Server error: ${response.statusCode}");
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<List<Map<String, dynamic>>> fetchEmotionTimeline() async {
    final headers = <String, String>{};
    if (_hasAuth) {
      headers["Authorization"] = "Bearer $_accessToken";
    }
    final response = await http.get(
      Uri.parse("$baseUrl/chat/timeline?user_id=$_effectiveUserId"),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception("Server error: ${response.statusCode}");
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> fetchWeeklyInsight() async {
    final headers = <String, String>{};
    if (_hasAuth) {
      headers["Authorization"] = "Bearer $_accessToken";
    }
    final response = await http.get(
      Uri.parse("$baseUrl/chat/weekly-insight?user_id=$_effectiveUserId"),
      headers: headers,
    );
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
