import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import 'mood_insights_screen.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {

  bool isDark = true;
  bool _isTyping = false;
  bool _isLoadingHistory = false;
  bool _isRecording = false;
  bool _isLoggedIn = false;
  String? _userEmail;

  final ChatService _chatService = ChatService();
  final AudioRecorder _audioRecorder = AudioRecorder();

  late final Ticker _bgTicker;
  double _bgTime = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  final TextEditingController _textController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  List<Map<String, dynamic>> messages = [];
  String? _recordingPath;
  int _messageSeq = 0;

  @override
  void initState() {
    super.initState();
    _restoreAuthSession();
    _bgTicker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        _bgTime = elapsed.inMilliseconds / 1000.0;
      });
    })..start();
  }

  Future<void> _restoreAuthSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;
    if (session == null || user == null) return;

    ChatService.configureAuth(
      accessToken: session.accessToken,
      userId: user.id,
    );

    if (!mounted) return;
    setState(() {
      _isLoggedIn = true;
      _userEmail = user.email;
    });
  }

  @override
  void dispose() {
    _bgTicker.dispose();
    _audioRecorder.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty || _isLoadingHistory || _isRecording) return;

    setState(() {
      messages.add({
        "id": _messageSeq++,
        "role": "user",
        "text": message,
        "ts": DateTime.now(),
      });
      _isTyping = true;
    });

    _textController.clear();
    _scrollToBottom();

    try {
      final replyData = await _chatService.sendMessage(message);

      setState(() {
        _isTyping = false;
        messages.add({
          "id": _messageSeq++,
          "role": "bot",
          "text": "",
          "ts": DateTime.now(),
          "emotion": replyData.emotion,
          "confidence": replyData.confidence,
        });
      });
      final botIndex = messages.length - 1;
      _scrollToBottom();
      await _animateBotReply(botIndex, replyData.reply);
    } catch (e) {
      setState(() {
        _isTyping = false;
        messages.add({
          "id": _messageSeq++,
          "role": "bot",
          "text": "Error connecting to backend",
          "ts": DateTime.now(),
        });
      });
    }
  }

  Future<void> _animateBotReply(int index, String fullReply) async {
    final buffer = StringBuffer();

    for (int i = 0; i < fullReply.length; i++) {
      if (!mounted) return;
      buffer.write(fullReply[i]);

      setState(() {
        messages[index]["text"] = buffer.toString();
      });
      // Avoid excessive scroll animations during typewriter updates.
      if (i % 8 == 0 || i == fullReply.length - 1) {
        _scrollToBottom();
      }

      final ch = fullReply[i];
      final delay = (ch == "." || ch == "!" || ch == "?") ? 24 : 14;
      await Future.delayed(Duration(milliseconds: delay));
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      try {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        }
      } catch (_) {
        // Ignore transient scroll timing issues in debug mode.
      }
    });
  }

  Future<void> _startNewChat() async {
    Navigator.pop(context);
    setState(() {
      messages.clear();
      _isTyping = false;
    });
  }

  List<Map<String, dynamic>> _buildSessionsFromHistory(
      List<ChatMessage> history) {
    final sessions = <Map<String, dynamic>>[];
    final current = <Map<String, dynamic>>[];
    DateTime? lastTs;

    for (final m in history) {
      final ts = m.createdAt ?? DateTime.now();

      // Split sessions if there is a long inactivity gap.
      final last = lastTs;
      final shouldSplit = last != null && ts.difference(last).inMinutes > 30;
      if (shouldSplit && current.isNotEmpty) {
        sessions.add(_sessionFromMessages(current));
        current.clear();
      }

      current.add({
        "id": _messageSeq++,
        "role": m.role,
        "text": m.text,
        "ts": ts,
        "emotion": m.emotion,
        "confidence": m.confidence,
      });
      lastTs = ts;
    }

    if (current.isNotEmpty) {
      sessions.add(_sessionFromMessages(current));
    }

    return sessions.reversed.toList();
  }

  Map<String, dynamic> _sessionFromMessages(List<Map<String, dynamic>> msgs) {
    String title = "Chat";
    for (final m in msgs) {
      if (m["role"] == "user" && (m["text"]?.toString().trim().isNotEmpty ?? false)) {
        title = m["text"].toString().trim();
        break;
      }
    }
    if (title.length > 45) {
      title = "${title.substring(0, 45)}...";
    }

    final startedAt = msgs.first["ts"] as DateTime?;
    return {
      "title": title,
      "startedAt": startedAt,
      "messages": List<Map<String, dynamic>>.from(msgs),
    };
  }

  Color _emotionColor(String? emotion) {
    switch ((emotion ?? "").toLowerCase()) {
      case "joy":
        return const Color(0xFF7BD389);
      case "sadness":
        return const Color(0xFF5A7FFF);
      case "anger":
        return const Color(0xFFF77FBE);
      case "fear":
        return const Color(0xFFB892FF);
      case "neutral":
        return const Color(0xFF7FD1FF);
      case "surprise":
        return const Color(0xFFFFB26B);
      case "crisis":
        return const Color(0xFFFFB26B);
      default:
        return const Color(0xFF4FA3A5);
    }
  }

  Map<String, dynamic>? _latestBotMood() {
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m["role"] == "bot" &&
          (m["emotion"] != null || m["confidence"] != null)) {
        return m;
      }
    }
    return null;
  }

  Future<void> _openPreviousChatsPicker() async {
    Navigator.pop(context);
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final history = await _chatService.fetchHistory();
      final sessions = _buildSessionsFromHistory(history);

      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
      });

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF0E1621),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          if (sessions.isEmpty) {
            return const SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  "No previous chats yet.",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 14),
                const Text(
                  "Previous Chats",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final s = sessions[index];
                      final sessionMessages =
                          s["messages"] as List<Map<String, dynamic>>;
                      final ts = s["startedAt"] as DateTime?;
                      final subtitle = ts == null
                          ? "Unknown time"
                          : "${ts.day.toString().padLeft(2, '0')}/${ts.month.toString().padLeft(2, '0')}  ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}";
                      String? dominantEmotion;
                      int emotionCount = 0;
                      for (final msg in sessionMessages) {
                        if (msg["role"] == "bot" &&
                            msg["emotion"] != null &&
                            msg["emotion"].toString().trim().isNotEmpty) {
                          emotionCount++;
                        }
                      }
                      if (emotionCount > 0) {
                        final counts = <String, int>{};
                        for (final msg in sessionMessages) {
                          final e = msg["emotion"]?.toString();
                          if (e == null || e.trim().isEmpty) continue;
                          counts[e] = (counts[e] ?? 0) + 1;
                        }
                        if (counts.isNotEmpty) {
                          dominantEmotion = counts.entries
                              .reduce((a, b) => a.value >= b.value ? a : b)
                              .key;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              messages = List<Map<String, dynamic>>.from(
                                  sessionMessages);
                              _isTyping = false;
                            });
                            _scrollToBottom();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.08),
                                  const Color(0xFF5A7FFF).withOpacity(0.12),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s["title"] as String,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        subtitle,
                                        style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${sessionMessages.length} msgs",
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 12),
                                    ),
                                    if (dominantEmotion != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _emotionColor(dominantEmotion)
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color:
                                                _emotionColor(dominantEmotion),
                                          ),
                                        ),
                                        child: Text(
                                          dominantEmotion!.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not load previous chats: $e")),
      );
    }
  }

  Future<void> _onMicPressed() async {
    if (_isTyping || _isLoadingHistory) return;

    try {
      if (_isRecording) {
        await _stopRecordingAndSend();
        return;
      }

      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission denied")),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = p.join(
        tempDir.path,
        "emc_${DateTime.now().millisecondsSinceEpoch}.m4a",
      );

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingPath = filePath;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Voice start failed: $e")),
      );
    }
  }

  Future<void> _openAuthSheet() async {
    Navigator.pop(context);
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1621),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _AuthSheet(),
    );

    if (result == null || !mounted) return;

    final email = result["email"]?.trim() ?? "";
    final password = result["password"]?.trim() ?? "";
    final mode = result["mode"] ?? "login";

    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid email and 6+ char password")),
      );
      return;
    }

    try {
      Session? session;
      User? user;

      if (mode == "signup") {
        final res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        session = res.session;
        user = res.user;
        if (session == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Signup done. Verify email, then login.")),
          );
          return;
        }
      } else {
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        session = res.session;
        user = res.user;
      }

      if (session == null || user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Auth failed. Try again.")),
        );
        return;
      }

      ChatService.configureAuth(
        accessToken: session.accessToken,
        userId: user.id,
      );

      setState(() {
        _isLoggedIn = true;
        _userEmail = user!.email ?? email;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Logged in as ${_userEmail ?? 'user'}")),
      );
    } on AuthException catch (e) {
      if (e is AuthApiException && e.code == "email_not_confirmed") {
        try {
          await Supabase.instance.client.auth.resend(
            type: OtpType.signup,
            email: email,
          );
        } catch (_) {
          // Ignore resend failures; main guidance still shown.
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Email not confirmed. Check inbox/spam and verify first."),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Auth error: ${e.message}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Auth error: $e")),
      );
    }
  }

  void _logout() async {
    Navigator.pop(context);
    await Supabase.instance.client.auth.signOut();
    ChatService.clearAuth();
    setState(() {
      _isLoggedIn = false;
      _userEmail = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Logged out")),
    );
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final stoppedPath = await _audioRecorder.stop();

      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });

      final filePath = stoppedPath ?? _recordingPath;
      _recordingPath = null;

      if (filePath == null || filePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No audio captured. Please try again.")),
        );
        return;
      }

      setState(() {
        messages.add({
          "id": _messageSeq++,
          "role": "user",
          "text": "Voice message",
          "ts": DateTime.now(),
        });
        _isTyping = true;
      });
      _scrollToBottom();

      final replyData = await _chatService.sendVoiceMessage(filePath);

      setState(() {
        _isTyping = false;
        messages.add({
          "id": _messageSeq++,
          "role": "bot",
          "text": "",
          "ts": DateTime.now(),
          "emotion": replyData.emotion,
          "confidence": replyData.confidence,
        });
      });
      final botIndex = messages.length - 1;
      _scrollToBottom();
      await _animateBotReply(botIndex, replyData.reply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Voice send failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    final bgColor =
        isDark ? const Color(0xFF0A1428) : Colors.white;

    final textColor =
        isDark ? Colors.white : Colors.black87;

    final inputColor =
        isDark ? const Color(0xFF4C5AA6) : const Color(0xFFB8C3F6);
    final latestMood = _latestBotMood();
    final ringEmotion = latestMood?["emotion"]?.toString();
    final ringConfidence = latestMood?["confidence"] is num
        ? (latestMood?["confidence"] as num).toDouble()
        : 0.35;
    final ringColor = _emotionColor(ringEmotion);
    final ringGlow = 10 + (18 * ringConfidence.clamp(0.0, 1.0));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: _buildDrawer(),

      body: Stack(
        children: [

          /// Animated bubbles
          Stack(children: _buildBubbles()),

          /// Blur layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
            child: Container(color: Colors.transparent),
          ),

          Column(
            children: [

              /// Top bar
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.menu,
                            color: textColor),
                        onPressed: () {
                          _scaffoldKey.currentState
                              ?.openDrawer();
                        },
                      ),
                      Text(
                        "EmoCare",
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: 0.2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isDark
                              ? Icons.light_mode
                              : Icons.dark_mode,
                          color: textColor,
                        ),
                        onPressed: () {
                          setState(() {
                            isDark = !isDark;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              /// Chat area
              Expanded(
                child: _isLoadingHistory
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40),
                          child: Text(
                            "“I’m here with you.\nWhat’s on your mind today?”",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            messages.length +
                                (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {

                          if (_isTyping &&
                              index ==
                                  messages.length) {
                            return _typingIndicator();
                          }

                          final msg = messages[index];
                          final isUser = msg["role"] == "user";
                          final msgTs = msg["ts"] as DateTime?;
                          final msgId = msg["id"] ?? index;
                          final emotion = msg["emotion"]?.toString();
                          final confidence = msg["confidence"] is num
                              ? (msg["confidence"] as num).toDouble()
                              : null;
                          final timeLabel = msgTs == null
                              ? ""
                              : "${msgTs.hour.toString().padLeft(2, '0')}:${msgTs.minute.toString().padLeft(2, '0')}";

                          if (isUser) {
                            return TweenAnimationBuilder<double>(
                              key: ValueKey("msg_$msgId"),
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, child) {
                                return Opacity(
                                  opacity: v,
                                  child: Transform.translate(
                                    offset: Offset(18 * (1 - v), 0),
                                    child: child,
                                  ),
                                );
                              },
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      padding: const EdgeInsets.all(14),
                                      constraints: const BoxConstraints(maxWidth: 280),
                                      decoration: BoxDecoration(
                                        color: inputColor,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        msg["text"] ?? "",
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    if (timeLabel.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                                        child: Text(
                                          timeLabel,
                                          style: TextStyle(
                                            color: isDark ? Colors.white54 : Colors.black45,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return TweenAnimationBuilder<double>(
                            key: ValueKey("msg_$msgId"),
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, child) {
                              return Opacity(
                                opacity: v,
                                child: Transform.translate(
                                  offset: Offset(-14 * (1 - v), 0),
                                  child: child,
                                ),
                              );
                            },
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      msg["text"] ?? "",
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                    if (timeLabel.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4, left: 2),
                                        child: Text(
                                          timeLabel,
                                          style: TextStyle(
                                            color: isDark ? Colors.white54 : Colors.black45,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    if (emotion != null || confidence != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: _moodChips(
                                          emotion: emotion,
                                          confidence: confidence,
                                          isDark: isDark,
                                          seed: msgId is int ? msgId : index,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              /// Glass input
              Padding(
                padding: const EdgeInsets.only(
                    left: 20, right: 20, bottom: 25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1,
                            child: child,
                          ),
                        );
                      },
                      child: _isRecording
                          ? Padding(
                              key: const ValueKey("record_status"),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5A7FFF).withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                                ),
                                child: const Text(
                                  "Recording... tap stop to send",
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey("record_status_empty")),
                    ),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                            sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 8),
                          decoration:
                              BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.05),
                            borderRadius:
                                BorderRadius.circular(30),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.1),
                            ),
                            boxShadow:
                                _textController.text
                                        .isNotEmpty
                                    ? [
                                        BoxShadow(
                                          color: const Color(
                                                  0xFF5A7FFF)
                                              .withOpacity(
                                                  0.4),
                                          blurRadius: 20,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : [],
                          ),
                          child: Row(
                            children: [

                              Expanded(
                                child: TextField(
                                  controller:
                                      _textController,
                                  style: TextStyle(
                                      color: textColor),
                                  cursorColor:
                                      textColor,
                                  onChanged: (_) {
                                    setState(() {
                                      if (_textController.text.trim().isNotEmpty) {
                                        _isTyping = false;
                                      }
                                    });
                                  },
                                  minLines: 1,
                                  maxLines: 4,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  decoration:
                                      InputDecoration(
                                    hintText:
                                        _isTyping ? "EmoCare is replying..." : "Ask EmoCare",
                                    hintStyle:
                                        TextStyle(
                                      color: isDark
                                          ? Colors
                                              .white70
                                          : Colors
                                              .black54,
                                    ),
                                    border:
                                        InputBorder.none,
                                  ),
                                ),
                              ),

                              GestureDetector(
                                onTap: _onMicPressed,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 320),
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _isRecording
                                          ? const Color(0xFF8AA0FF)
                                          : ringColor.withOpacity(0.9),
                                      width: _isRecording ? 2.4 : 2.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isRecording
                                                ? const Color(0xFF8AA0FF)
                                                : ringColor)
                                            .withOpacity(0.45),
                                        blurRadius:
                                            _isRecording ? 24 : ringGlow,
                                        spreadRadius: _isRecording ? 2 : 1,
                                      ),
                                    ],
                                    color: isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.black.withOpacity(0.05),
                                  ),
                                  child: Icon(
                                    _isRecording ? Icons.stop_circle : Icons.mic,
                                    color: _isRecording
                                        ? const Color(0xFF8AA0FF)
                                        : textColor,
                                  ),
                                ),
                              ),

                              if (_textController.text
                                      .trim()
                                      .isNotEmpty ||
                                  _isTyping)
                                IconButton(
                                  icon: Icon(
                                    _textController.text.trim().isNotEmpty
                                        ? Icons.send
                                        : Icons.hourglass_top_rounded,
                                    color: _textController.text.trim().isNotEmpty
                                        ? textColor
                                        : (isDark ? Colors.white54 : Colors.black45),
                                  ),
                                  onPressed: _textController.text.trim().isNotEmpty
                                      ? _sendMessage
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin:
            const EdgeInsets.symmetric(vertical: 6),
        padding:
            const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius:
              BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: const [
            _Dot(),
            SizedBox(width: 4),
            _Dot(delay: 200),
            SizedBox(width: 4),
            _Dot(delay: 400),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration:
            const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0E1621),
              Color(0xFF1A2A4F),
            ],
            begin:
                Alignment.topLeft,
            end: Alignment
                .bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Row(
                children: [
                  Image.asset(
                    "assets/Logo12.png",
                    height: 40,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "EmoCare :)",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _drawerItem(Icons.add_comment, "New Chat", onTap: _startNewChat),
              _drawerItem(Icons.history, "Previous Chats", onTap: _openPreviousChatsPicker),
              _drawerItem(
                Icons.psychology,
                "Mood Insights",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MoodInsightsScreen(),
                    ),
                  );
                },
              ),
              const Spacer(),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white70),
                title: const Text(
                  "Settings",
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              _drawerItem(Icons.info_outline, "About"),
              ListTile(
                leading: Icon(
                  _isLoggedIn ? Icons.verified_user : Icons.login,
                  color: Colors.white70,
                ),
                title: Text(
                  _isLoggedIn
                      ? (_userEmail ?? "Logged in")
                      : "Login / Create Account",
                  style: const TextStyle(color: Colors.white70),
                ),
                subtitle: Text(
                  _isLoggedIn
                      ? "You are signed in"
                      : "Optional: continue in guest mode",
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onTap: _isLoggedIn ? null : _openAuthSheet,
              ),
              if (_isLoggedIn)
                _drawerItem(Icons.logout, "Logout", onTap: _logout),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(
      IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading:
          Icon(icon,
              color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(
            color: Colors.white70),
      ),
      onTap: onTap ?? () {},
    );
  }

  Widget _moodChips({
    required String? emotion,
    required double? confidence,
    required bool isDark,
    required int seed,
  }) {
    final chipColor = isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08);
    final chipText = isDark ? Colors.white : Colors.black87;

    final chips = <Widget>[];
    if (emotion != null && emotion.trim().isNotEmpty) {
      chips.add(
        _AnimatedMoodChip(
          delayMs: 40 + (seed % 5) * 8,
          child: _chip(
            icon: Icons.psychology_alt_rounded,
            label: emotion.toUpperCase(),
            bg: chipColor,
            textColor: chipText,
          ),
        ),
      );
    }
    if (confidence != null) {
      chips.add(
        _AnimatedMoodChip(
          delayMs: 130 + (seed % 5) * 8,
          child: _chip(
            icon: Icons.insights_rounded,
            label: "${(confidence * 100).toStringAsFixed(0)}%",
            bg: chipColor,
            textColor: chipText,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color bg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor.withOpacity(0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.25,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBubbles() {
    final double t = _bgTime;

    return [
      Positioned(
        top: -100 + sin(t * 0.35) * 30,
        right: -80 + cos(t * 0.32) * 25,
        child: _bubble(
            300,
            const Color(0xFF5A7FFF)
                .withOpacity(0.4)),
      ),
      Positioned(
        bottom: -150 +
            cos(t * 0.28) *
                35,
        left: -100 +
            sin(t * 0.26) *
                30,
        child: _bubble(
            350,
            const Color(0xFF4FA3A5)
                .withOpacity(0.4)),
      ),
      Positioned(
        top: 200 +
            sin(t * 0.41) *
                40,
        left: -120 +
            cos(t * 0.37) *
                35,
        child: _bubble(
            280,
            const Color(0xFF5A7FFF)
                .withOpacity(0.4)),
      ),
    ];
  }

  Widget _bubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({this.delay = 0});

  @override
  State<_Dot> createState() =>
      _DotState();
}

class _DotState extends State<_Dot>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 800),
    );

    Future.delayed(
        Duration(milliseconds: widget.delay),
        () {
      if (mounted) {
        _controller.repeat(
            reverse: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(
              begin: 0.3,
              end: 1.0)
          .animate(_controller),
      child: Container(
        width: 6,
        height: 6,
        decoration:
            const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _AnimatedMoodChip extends StatelessWidget {
  final int delayMs;
  final Widget child;

  const _AnimatedMoodChip({
    required this.delayMs,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 340 + delayMs),
      curve: Curves.easeOutBack,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        final scale = 0.86 + (0.14 * t);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _AuthSheet extends StatefulWidget {
  const _AuthSheet();

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid email and 6+ char password")),
      );
      return;
    }

    Navigator.pop(context, {
      "email": email,
      "password": password,
      "mode": _isSignUp ? "signup" : "login",
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isSignUp ? "Create account" : "Login",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Optional: you can continue as guest anytime.",
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Email",
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Password",
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A7FFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(_isSignUp ? "Create Account" : "Login"),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => setState(() => _isSignUp = !_isSignUp),
              child: Text(
                _isSignUp
                    ? "Already have an account? Login"
                    : "No account? Create one",
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
