import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'chat_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const int _targetCycles = 3;

  bool isDark = true;
  bool _showBreathing = false;
  int _completedCycles = 0;

  late AnimationController _bgController;
  late Animation<double> _bgAnimation;
  late AnimationController _breathController;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);

    _bgAnimation = CurvedAnimation(
      parent: _bgController,
      curve: Curves.easeInOut,
    );

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _completedCycles = min(_completedCycles + 1, _targetCycles);
          });

          if (_completedCycles < _targetCycles) {
            _breathController.forward(from: 0);
          }
        }
      });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  void _openChat() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );
  }

  void _startBreathing() {
    setState(() {
      _showBreathing = true;
      _completedCycles = 0;
    });
    _breathController.forward(from: 0);
  }

  String _breathPrompt(double t) {
    if (_completedCycles >= _targetCycles) return "Great. You are ready.";
    if (t < 0.4) return "Inhale";
    if (t < 0.6) return "Hold";
    return "Exhale";
  }

  double _breathScale(double t) {
    if (t < 0.4) {
      final p = t / 0.4;
      return 0.84 + (0.24 * p);
    }
    if (t < 0.6) return 1.08;
    final p = (t - 0.6) / 0.4;
    return 1.08 - (0.24 * p);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF0E1621) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          if (isDark) ..._darkBubbles(),
          if (!isDark) ..._lightBubbles(),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
            child: Container(color: Colors.transparent),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: IconButton(
                      icon: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                        color: textColor,
                      ),
                      onPressed: () {
                        setState(() {
                          isDark = !isDark;
                        });
                      },
                    ),
                  ),
                ),
                const Spacer(),
                if (!_showBreathing)
                  Text(
                    "It's okay to slow down,\nfor a moment.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  )
                else
                  AnimatedBuilder(
                    animation: _breathController,
                    builder: (context, child) {
                      final t = _breathController.value;
                      final scale = _breathScale(t);
                      return Column(
                        children: [
                          Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [
                                    Color(0xFF7DA0FF),
                                    Color(0xFF4FA3A5),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF5A7FFF).withOpacity(0.35),
                                    blurRadius: 30,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _breathPrompt(t),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Cycle ${min(_completedCycles + 1, _targetCycles)} of $_targetCycles",
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 28),
                _buildActionButtons(),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _darkBubbles() {
    return [
      Positioned(
        top: -100,
        right: -80,
        child: _animatedBubble(
          size: 300,
          color: const Color(0xFF5A7FFF).withOpacity(0.3),
          moveX: 25,
          moveY: -15,
        ),
      ),
      Positioned(
        bottom: -150,
        left: -100,
        child: _animatedBubble(
          size: 350,
          color: const Color(0xFF4FA3A5).withOpacity(0.3),
          moveX: -20,
          moveY: 20,
        ),
      ),
    ];
  }

  List<Widget> _lightBubbles() {
    return [
      Positioned(
        top: -120,
        left: -80,
        child: _animatedBubble(
          size: 300,
          color: const Color(0xFF4FA3A5).withOpacity(0.3),
          moveX: 20,
          moveY: 15,
        ),
      ),
      Positioned(
        bottom: -150,
        right: -100,
        child: _animatedBubble(
          size: 350,
          color: const Color(0xFF5A7FFF).withOpacity(0.3),
          moveX: -25,
          moveY: -20,
        ),
      ),
    ];
  }

  Widget _buildActionButtons() {
    return Transform.translate(
      offset: const Offset(0, 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF5A7FFF),
                    Color(0xFF4FA3A5),
                  ],
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (!_showBreathing) {
                    _startBreathing();
                  } else {
                    _openChat();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  !_showBreathing
                      ? "Continue"
                      : (_completedCycles >= _targetCycles
                          ? "Start Chat"
                          : "Skip To Chat"),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: _openChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.09)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.26)
                              : Colors.black.withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        _showBreathing ? "End Exercise" : "Skip",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedBubble({
    required double size,
    required Color color,
    required double moveX,
    required double moveY,
  }) {
    return AnimatedBuilder(
      animation: _bgAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            moveX * _bgAnimation.value,
            moveY * _bgAnimation.value,
          ),
          child: child,
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
