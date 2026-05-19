import 'dart:math';
import 'package:flutter/material.dart';
import 'webview_screen.dart';
import 'app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Controllers ───────────────────────────────────────────────────────────
  late final AnimationController _particleCtrl;
  late final AnimationController _uiCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _orbitCtrl;   // vòng xoay orbital
  late final AnimationController _shimmerCtrl; // text shimmer
  late final AnimationController _waveCtrl;    // background wave
  late final AnimationController _matrixCtrl;  // matrix rain

  // ── UI animations ─────────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoRotate;
  late final Animation<Offset>  _titleSlide;
  late final Animation<double>  _titleOpacity;
  late final Animation<Offset>  _taglineSlide;
  late final Animation<double>  _taglineOpacity;
  late final Animation<double>  _dotsOpacity;
  late final Animation<double>  _glowPulse;
  late final Animation<double>  _bgScale;
  late final Animation<double>  _shimmer;
  late final Animation<double>  _orbit;
  late final Animation<double>  _wave;

  // ── Particles & Matrix ────────────────────────────────────────────────────
  final List<_Particle> _particles = [];
  final List<_MatrixDrop> _matrixDrops = [];
  final Random _rng = Random();
  bool _particlesInited = false;

  @override
  void initState() {
    super.initState();

    // Particle tick
    _particleCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 16))..repeat();

    // Glow pulse
    _glowCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _glowPulse = Tween<double>(begin: 0.80, end: 1.22).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Orbital rings rotation
    _orbitCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3000))..repeat();
    _orbit = Tween<double>(begin: 0, end: 2 * pi).animate(
        CurvedAnimation(parent: _orbitCtrl, curve: Curves.linear));

    // Text shimmer
    _shimmerCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000))..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    // Background wave
    _waveCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 4000))..repeat();
    _wave = Tween<double>(begin: 0, end: 2 * pi).animate(
        CurvedAnimation(parent: _waveCtrl, curve: Curves.linear));

    // Matrix rain tick
    _matrixCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 80))..repeat();

    // Background scale breathe
    _uiCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2200))..forward();

    _bgScale = Tween<double>(begin: 1.08, end: 1.0).animate(
        CurvedAnimation(parent: _uiCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)));

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _uiCtrl,
            curve: const Interval(0.05, 0.45, curve: Curves.elasticOut)));

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _uiCtrl,
            curve: const Interval(0.05, 0.28, curve: Curves.easeIn)));

    _logoRotate = Tween<double>(begin: -0.3, end: 0.0).animate(
        CurvedAnimation(parent: _uiCtrl,
            curve: const Interval(0.05, 0.45, curve: Curves.elasticOut)));

    _titleSlide = Tween<Offset>(begin: const Offset(0, 1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _uiCtrl,
            curve: const Interval(0.32, 0.65, curve: Curves.easeOutCubic)));

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _uiCtrl,
            curve: const Interval(0.32, 0.55, curve: Curves.easeIn)));

    _taglineSlide = Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _uiCtrl,
            curve: const Interval(0.48, 0.78, curve: Curves.easeOutCubic)));

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _uiCtrl,
            curve: const Interval(0.48, 0.68, curve: Curves.easeIn)));

    _dotsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _uiCtrl,
            curve: const Interval(0.65, 0.95, curve: Curves.easeIn)));

    // Navigate after 3s
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const WebViewScreen(),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeInOut);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.04, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ));
    });
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _uiCtrl.dispose();
    _glowCtrl.dispose();
    _orbitCtrl.dispose();
    _shimmerCtrl.dispose();
    _waveCtrl.dispose();
    _matrixCtrl.dispose();
    super.dispose();
  }

  void _initParticles(double w, double h) {
    if (_particlesInited) return;
    _particlesInited = true;
    for (int i = 0; i < 70; i++) _particles.add(_Particle(_rng, w, h));
    // Matrix columns
    final cols = (w / 18).floor();
    for (int i = 0; i < cols; i++) {
      _matrixDrops.add(_MatrixDrop(_rng, w, h, i));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _initParticles(size.width, size.height);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Animated background gradient ─────────────
          AnimatedBuilder(
            animation: _wave,
            builder: (_, __) => CustomPaint(
              painter: _WaveBgPainter(_wave.value),
              size: size,
            ),
          ),

          // ── Matrix rain (subtle) ─────────────────────
          AnimatedBuilder(
            animation: _matrixCtrl,
            builder: (_, __) {
              for (final d in _matrixDrops) d.update(_rng, size.height);
              return CustomPaint(
                painter: _MatrixPainter(List.unmodifiable(_matrixDrops)),
                size: size,
              );
            },
          ),

          // ── Particles ────────────────────────────────
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) {
              for (final p in _particles) p.update(_rng, size.width, size.height);
              return CustomPaint(
                painter: _ParticlePainter(List.unmodifiable(_particles)),
                size: size,
              );
            },
          ),

          // ── Center content ───────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // Logo area
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [

                      // Outer glow rings (pulsing)
                      AnimatedBuilder(
                        animation: Listenable.merge([_glowPulse, _orbit]),
                        builder: (_, __) => Stack(
                          alignment: Alignment.center,
                          children: [
                            _GlowRing(size: 220 * _glowPulse.value,
                                color: AppTheme.primary.withOpacity(0.04)),
                            _GlowRing(size: 185 * _glowPulse.value,
                                color: AppTheme.primary.withOpacity(0.08)),
                            _GlowRing(size: 155 * _glowPulse.value,
                                color: AppTheme.accentPink.withOpacity(0.10)),
                            _GlowRing(size: 130,
                                color: AppTheme.primary.withOpacity(0.22)),

                            // Orbital ring (rotating dashed)
                            Transform.rotate(
                              angle: _orbit.value,
                              child: CustomPaint(
                                size: const Size(168, 168),
                                painter: _OrbitalRingPainter(
                                    color: AppTheme.primary.withOpacity(0.5),
                                    dashCount: 12,
                                    strokeWidth: 1.8),
                              ),
                            ),
                            // Reverse orbit
                            Transform.rotate(
                              angle: -_orbit.value * 0.6,
                              child: CustomPaint(
                                size: const Size(140, 140),
                                painter: _OrbitalRingPainter(
                                    color: AppTheme.accentPink.withOpacity(0.4),
                                    dashCount: 8,
                                    strokeWidth: 1.2),
                              ),
                            ),

                            // Orbiting dots
                            ..._buildOrbitingDots(_orbit.value),
                          ],
                        ),
                      ),

                      // Logo image
                      AnimatedBuilder(
                        animation: _uiCtrl,
                        builder: (_, child) => Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Transform.rotate(
                              angle: _logoRotate.value,
                              child: child,
                            ),
                          ),
                        ),
                        child: Container(
                          width: 118,
                          height: 118,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.6),
                                blurRadius: 36,
                                spreadRadius: 6,
                              ),
                              BoxShadow(
                                color: AppTheme.accentPink.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Image.asset('assets/images/ic_logo.png',
                                fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Title với shimmer effect
                AnimatedBuilder(
                  animation: _uiCtrl,
                  builder: (_, child) => FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(position: _titleSlide, child: child),
                  ),
                  child: AnimatedBuilder(
                    animation: _shimmer,
                    builder: (_, __) => ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment(_shimmer.value - 1, 0),
                        end: Alignment(_shimmer.value + 0.4, 0),
                        colors: const [
                          Color(0xFFFF6B35),
                          Color(0xFFFFEE00),
                          Color(0xFFFFFFFF),
                          Color(0xFFFFD000),
                          Color(0xFFFF4757),
                        ],
                        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                      ).createShader(bounds),
                      child: const Text(
                        'TikDown',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 3.0,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Tagline
                AnimatedBuilder(
                  animation: _uiCtrl,
                  builder: (_, child) => FadeTransition(
                    opacity: _taglineOpacity,
                    child: SlideTransition(position: _taglineSlide, child: child),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.4), width: 1),
                      color: AppTheme.primary.withOpacity(0.08),
                    ),
                    child: const Text(
                      '⚡  Tải video nhanh chóng  ·  Dễ dàng',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xCCFF8A60),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Loading dots ─────────────────────────────
          Positioned(
            bottom: 70,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _uiCtrl,
              builder: (_, child) =>
                  Opacity(opacity: _dotsOpacity.value, child: child),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PulsingDot(color: AppTheme.primary, delay: Duration.zero),
                      const SizedBox(width: 14),
                      _PulsingDot(color: AppTheme.accentYellow,
                          delay: const Duration(milliseconds: 200)),
                      const SizedBox(width: 14),
                      _PulsingDot(color: AppTheme.accentPink,
                          delay: const Duration(milliseconds: 400)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Đang kết nối...',
                    style: TextStyle(
                      color: Color(0x66FFFFFF),
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Version tag ──────────────────────────────
          const Positioned(
            bottom: 18,
            right: 22,
            child: Text(
              'v2.1',
              style: TextStyle(color: Color(0x33FFFFFF), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOrbitingDots(double angle) {
    return List.generate(3, (i) {
      final a = angle + (2 * pi / 3) * i;
      const r = 84.0;
      return Positioned(
        left: 120 + r * cos(a) - 5,
        top:  120 + r * sin(a) - 5,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.particleColors[i * 2],
            boxShadow: [
              BoxShadow(
                color: AppTheme.particleColors[i * 2].withOpacity(0.9),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ─── Wave Background ──────────────────────────────────────────────────────────
class _WaveBgPainter extends CustomPainter {
  final double phase;
  _WaveBgPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    // Base radial
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.4,
        colors: const [Color(0xFF1F0A3A), Color(0xFF0D0D1A)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Subtle wave overlay
    final wavePaint = Paint()
      ..color = AppTheme.primary.withOpacity(0.025)
      ..style = PaintingStyle.fill;

    for (int w = 0; w < 3; w++) {
      final path = Path();
      path.moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 4) {
        final y = size.height * 0.7 +
            sin(x / size.width * 2 * pi + phase + w * 1.2) * (30 + w * 15);
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveBgPainter old) => old.phase != phase;
}

// ─── Orbital Ring Painter ─────────────────────────────────────────────────────
class _OrbitalRingPainter extends CustomPainter {
  final Color color;
  final int dashCount;
  final double strokeWidth;
  _OrbitalRingPainter({required this.color, required this.dashCount, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final r = size.width / 2;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final dashAngle = pi / dashCount;

    for (int i = 0; i < dashCount; i++) {
      final start = i * 2 * dashAngle;
      final sweep = dashAngle * 0.6;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start, sweep, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Matrix Rain ──────────────────────────────────────────────────────────────
class _MatrixDrop {
  double x, y, speed;
  String char;
  double alpha;

  _MatrixDrop(Random rng, double w, double h, int col)
      : x = col * 18.0,
        y = rng.nextDouble() * h,
        speed = 1.5 + rng.nextDouble() * 3,
        char = _randomChar(rng),
        alpha = 0.03 + rng.nextDouble() * 0.08;

  static String _randomChar(Random r) {
    const chars = 'アイウエオカキクケコ01ガギグゲゴサシスセソ';
    return chars[r.nextInt(chars.length)];
  }

  void update(Random rng, double h) {
    y += speed;
    if (y > h + 20) {
      y = -20;
      speed = 1.5 + rng.nextDouble() * 3;
      alpha = 0.03 + rng.nextDouble() * 0.08;
    }
    if (rng.nextDouble() < 0.05) char = _randomChar(rng);
  }
}

class _MatrixPainter extends CustomPainter {
  final List<_MatrixDrop> drops;
  _MatrixPainter(this.drops);

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in drops) {
      final tp = TextPainter(
        text: TextSpan(
          text: d.char,
          style: TextStyle(
            color: AppTheme.primary.withOpacity(d.alpha),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(d.x, d.y));
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixPainter old) => true;
}

// ─── Glow Ring ────────────────────────────────────────────────────────────────
class _GlowRing extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowRing({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

// ─── Pulsing Dot ──────────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  final Duration delay;
  const _PulsingDot({required this.color, required this.delay});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700));
    _anim = Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () { if (mounted) _ctrl.repeat(reverse: true); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                  color: widget.color.withOpacity(0.8),
                  blurRadius: 12, spreadRadius: 2)],
            ),
          ),
        ),
      );
}

// ─── Particle ─────────────────────────────────────────────────────────────────
class _Particle {
  double x, y, vx, vy, size, alpha;
  int alphaDir;
  Color color;

  _Particle(Random rng, double w, double h)
      : x = rng.nextDouble() * w,
        y = rng.nextDouble() * h,
        size = 1.2 + rng.nextDouble() * 3.2,
        alpha = 0.1 + rng.nextDouble() * 0.8,
        alphaDir = 1,
        color = AppTheme.particleColors[rng.nextInt(AppTheme.particleColors.length)],
        vx = 0, vy = 0 {
    _rndVel(rng);
  }

  void _rndVel(Random r) {
    final spd = 0.2 + r.nextDouble() * 0.9;
    final ang = r.nextDouble() * 2 * pi;
    vx = cos(ang) * spd;
    vy = sin(ang) * spd - 0.28;
  }

  void update(Random rng, double w, double h) {
    x += vx; y += vy;
    alpha += 0.006 * alphaDir;
    if (alpha >= 1.0) { alpha = 1.0; alphaDir = -1; }
    if (alpha <= 0.0) { alpha = 0.0; alphaDir = 1; }
    if (x < -10 || x > w + 10 || y < -10 || y > h + 10) {
      x = rng.nextDouble() * w;
      y = h + 5;
      color = AppTheme.particleColors[rng.nextInt(AppTheme.particleColors.length)];
      _rndVel(rng);
    }
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      canvas.drawCircle(
        Offset(p.x, p.y), p.size,
        Paint()
          ..color = p.color.withOpacity(p.alpha.clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
