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
  // Controllers
  late final AnimationController _particleCtrl; // tick nhanh → drives particles
  late final AnimationController _uiCtrl;       // 0→1 trong 2s → drives UI
  late final AnimationController _glowCtrl;     // pulse glow rings liên tục

  // UI animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset>  _titleSlide;
  late final Animation<double>  _titleOpacity;
  late final Animation<Offset>  _taglineSlide;
  late final Animation<double>  _taglineOpacity;
  late final Animation<double>  _dotsOpacity;
  late final Animation<double>  _glowPulse;

  // Particles
  final List<Particle> _particles = [];
  final Random _rng = Random();
  bool _particlesInited = false;

  @override
  void initState() {
    super.initState();

    // ── Particle tick (16ms ≈ 60fps) ──────────────────
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();

    // ── Glow pulse ────────────────────────────────────
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowPulse = Tween<double>(begin: 0.85, end: 1.18).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // ── UI timeline (2000ms total) ────────────────────
    _uiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    _logoScale = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _uiCtrl,
          curve: const Interval(0.08, 0.50, curve: Curves.elasticOut)));

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _uiCtrl,
          curve: const Interval(0.08, 0.32, curve: Curves.easeIn)));

    _titleSlide = Tween<Offset>(
            begin: const Offset(0, 0.8), end: Offset.zero)
        .animate(CurvedAnimation(parent: _uiCtrl,
            curve: const Interval(0.30, 0.62, curve: Curves.easeOutCubic)));

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _uiCtrl,
          curve: const Interval(0.30, 0.55, curve: Curves.easeIn)));

    _taglineSlide = Tween<Offset>(
            begin: const Offset(0, 0.8), end: Offset.zero)
        .animate(CurvedAnimation(parent: _uiCtrl,
            curve: const Interval(0.44, 0.76, curve: Curves.easeOutCubic)));

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _uiCtrl,
          curve: const Interval(0.44, 0.68, curve: Curves.easeIn)));

    _dotsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _uiCtrl,
          curve: const Interval(0.62, 0.92, curve: Curves.easeIn)));

    // ── Navigate after 2.4s ───────────────────────────
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const WebViewScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ));
    });
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _uiCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _initParticles(double w, double h) {
    if (_particlesInited) return;
    _particlesInited = true;
    for (int i = 0; i < 58; i++) {
      _particles.add(Particle(_rng, w, h));
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
          // ── Background radial gradient ───────────────
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.3,
                colors: [Color(0xFF1F0B38), Color(0xFF0D0D1A)],
              ),
            ),
          ),

          // ── Particles ────────────────────────────────
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) {
              for (final p in _particles) {
                p.update(_rng, size.width, size.height);
              }
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
                // Logo + glow
                SizedBox(
                  width: 210,
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow rings (pulsing)
                      AnimatedBuilder(
                        animation: _glowPulse,
                        builder: (_, __) => Stack(
                          alignment: Alignment.center,
                          children: [
                            _GlowRing(size: 200 * _glowPulse.value,
                                color: AppTheme.primary.withOpacity(0.05)),
                            _GlowRing(size: 164 * _glowPulse.value,
                                color: AppTheme.primary.withOpacity(0.10)),
                            _GlowRing(size: 136 * _glowPulse.value,
                                color: AppTheme.primary.withOpacity(0.18)),
                            _GlowRing(size: 112, color: AppTheme.primary.withOpacity(0.28)),
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
                            child: child,
                          ),
                        ),
                        child: Container(
                          width: 115,
                          height: 115,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/ic_logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Title với gradient text
                AnimatedBuilder(
                  animation: _uiCtrl,
                  builder: (_, child) => FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(position: _titleSlide, child: child),
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFFF6B35),
                        Color(0xFFFFD000),
                        Color(0xFFFF6B35),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ).createShader(bounds),
                    child: const Text(
                      'TikDown',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.5,
                        height: 1.0,
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
                  child: const Text(
                    'Tai video nhanh chong  ·  De dang',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xCCFF8A60),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Loading dots ─────────────────────────────
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _uiCtrl,
              builder: (_, child) =>
                  Opacity(opacity: _dotsOpacity.value, child: child),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PulsingDot(color: AppTheme.primary,      delay: Duration.zero),
                  const SizedBox(width: 12),
                  _PulsingDot(color: AppTheme.accentYellow, delay: const Duration(milliseconds: 220)),
                  const SizedBox(width: 12),
                  _PulsingDot(color: AppTheme.accentPink,   delay: const Duration(milliseconds: 440)),
                ],
              ),
            ),
          ),

          // ── Version ──────────────────────────────────
          const Positioned(
            bottom: 18,
            right: 22,
            child: Text(
              'v2.0',
              style: TextStyle(color: Color(0x40FFFFFF), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Glow Ring Widget ─────────────────────────────────────────────────────────
class _GlowRing extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowRing({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _anim = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.7),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Particle Model ───────────────────────────────────────────────────────────
class Particle {
  double x, y, vx, vy, size, alpha;
  int alphaDir;
  Color color;

  Particle(Random rng, double w, double h)
      : x = rng.nextDouble() * w,
        y = rng.nextDouble() * h,
        size = 1.4 + rng.nextDouble() * 2.8,
        alpha = 0.15 + rng.nextDouble() * 0.75,
        alphaDir = 1,
        color = AppTheme.particleColors[
            rng.nextInt(AppTheme.particleColors.length)],
        vx = 0,
        vy = 0 {
    _randomVelocity(rng);
  }

  void _randomVelocity(Random rng) {
    final speed = 0.25 + rng.nextDouble() * 0.85;
    final angle = rng.nextDouble() * 2 * pi;
    vx = cos(angle) * speed;
    vy = sin(angle) * speed - 0.30; // slight upward drift
  }

  void update(Random rng, double w, double h) {
    x += vx;
    y += vy;
    alpha += 0.007 * alphaDir;
    if (alpha >= 1.0) { alpha = 1.0; alphaDir = -1; }
    if (alpha <= 0.0) { alpha = 0.0; alphaDir = 1; }
    if (x < -10 || x > w + 10 || y < -10 || y > h + 10) {
      x = rng.nextDouble() * w;
      y = h + 5;
      color = AppTheme.particleColors[rng.nextInt(AppTheme.particleColors.length)];
      _randomVelocity(rng);
    }
  }
}

// ─── Particle Painter ─────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.alpha.clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2.2);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
