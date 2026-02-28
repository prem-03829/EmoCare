import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'chat_screen.dart'; // ← assuming this exists

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
    final bgColor =
        isDark ? const Color.fromARGB(255, 37, 34, 71) : Colors.white;
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
                      onPressed: () => setState(() => isDark = !isDark),
                    ),
                  ),
                ),
                const Spacer(flex: 7),
                if (!_showBreathing)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.32,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black87,
                        shadows: isDark
                            ? [
                                Shadow(
                                  color:
                                      const Color(0xFF7DA0FF).withOpacity(0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 4),
                                ),
                                Shadow(
                                  color:
                                      const Color(0xFF4FA3A5).withOpacity(0.25),
                                  blurRadius: 32,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      textAlign: TextAlign.center,
                      child:
                          const Text("It's okay to slow down,\nfor a moment."),
                    ),
                  )
                else
                  AnimatedBuilder(
                    animation: _breathController,
                    builder: (context, _) {
                      final t = _breathController.value;
                      final scale = _breathScale(t);

                      return Column(
                        children: [
                          Transform.scale(
                            scale: scale,
                            child: SizedBox(
                              width: 180,
                              height: 180,
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const RadialGradient(
                                        colors: [
                                          Color(0xFF8AB4FF),
                                          Color(0xFF5FC5C8)
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF6B8FFF)
                                              .withOpacity(0.5),
                                          blurRadius: 60,
                                          spreadRadius: 20,
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF4FA3A5)
                                              .withOpacity(0.4),
                                          blurRadius: 80,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: ClipOval(
                                      child: CustomPaint(
                                        painter: _BreathingNoisePainter(
                                          seed: (t * 1000).toInt() +
                                              _completedCycles * 97,
                                          darkMode: isDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            _breathPrompt(t),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color:
                                      const Color(0xFF7DA0FF).withOpacity(0.6),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Cycle ${min(_completedCycles + 1, _targetCycles)} of $_targetCycles",
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                const Spacer(
                    flex:
                        5), // ← was 4 → now more space above buttons → effectively shifts buttons up
                _buildActionButtons(),
                const SizedBox(height: 280), // ← was 40 → reduced by ~20px
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Primary button
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF5A7FFF),
                  Color(0xFF6B8CFF),
                  Color(0xFF7A9CFF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5A7FFF).withOpacity(0.50),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 2,
                ),
              ],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 38, vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
              child: Text(
                !_showBreathing
                    ? "Continue"
                    : (_completedCycles >= _targetCycles
                        ? "Start Chat"
                        : "Skip To Chat"),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          const SizedBox(
              width:
                  40), // ← increased from 16 to 24 → more distance between buttons

          // Secondary glass button
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.18 : 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isDark ? 0.06 : 0.09),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(isDark ? 0.18 : 0.13),
                      width: 1.1,
                    ),
                  ),
                  child: Text(
                    _showBreathing ? "End Exercise" : "Skip",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

class _BreathingNoisePainter extends CustomPainter {
  final int seed;
  final bool darkMode;

  _BreathingNoisePainter({
    required this.seed,
    required this.darkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final baseColor = darkMode ? Colors.white : Colors.black;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 220; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final alpha = darkMode
          ? (0.03 + random.nextDouble() * 0.07)
          : (0.015 + random.nextDouble() * 0.04);
      final radius = 0.3 + random.nextDouble() * 1.1;
      paint.color = baseColor.withOpacity(alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BreathingNoisePainter oldDelegate) {
    return seed != oldDelegate.seed || darkMode != oldDelegate.darkMode;
  }
}
