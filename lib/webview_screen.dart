import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with WidgetsBindingObserver {
  static const String _targetUrl = 'https://tikdown.ddns.net';

  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullRefresh;

  // UI state
  double  _progress   = 0;
  bool    _isLoading  = true;
  bool    _hasError   = false;
  String  _errorMsg   = '';
  bool    _isDownloading = false;

  // Download progress
  double  _dlProgress = 0;
  String  _dlFilename = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupPullRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupPullRefresh() {
    _pullRefresh = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: AppTheme.primary,
        backgroundColor: Colors.transparent,
        attributedTitle: AttributedString(text: 'Dang lam moi...'),
      ),
      onRefresh: () async {
        if (await _isOnline()) {
          _webViewController?.reload();
        } else {
          _pullRefresh?.endRefreshing();
          _showError('Khong co ket noi Internet.');
        }
      },
    );
  }

  InAppWebViewSettings _buildSettings() {
    return InAppWebViewSettings(
      // Core
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      useWideViewPort: true,
      loadWithOverviewMode: true,

      // Zoom
      supportZoom: true,
      builtInZoomControls: true,
      displayZoomControls: false,

      // Security
      mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
      allowFileAccess: false,
      allowContentAccess: false,
      thirdPartyCookiesEnabled: false,

      // Media
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,

      // Cache: dùng cache trước → tránh reload thừa
      cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,

      // Dark mode (Android 10+)
      algorithmicDarkeningAllowed: true,

      // Modern Chrome UA
      userAgent:
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/124.0.0.0 Mobile Safari/537.36',

      // Hiệu năng
      hardwareAcceleration: true,
      overScrollMode: OverScrollMode.NEVER,
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) => _handleBackPress(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              // ── WebView ───────────────────────────────
              AnimatedOpacity(
                opacity: _hasError ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_targetUrl)),
                  initialSettings: _buildSettings(),
                  pullToRefreshController: _pullRefresh,

                  onWebViewCreated: (ctrl) {
                    _webViewController = ctrl;
                    CookieManager.instance()
                        .acceptThirdPartyCookies(webViewController: ctrl, accept: false);
                  },

                  onLoadStart: (ctrl, url) {
                    setState(() {
                      _isLoading = true;
                      _progress  = 5;
                      _hasError  = false;
                    });
                  },

                  onProgressChanged: (ctrl, progress) {
                    setState(() => _progress = progress.toDouble());
                    if (progress == 100) _pullRefresh?.endRefreshing();
                  },

                  onLoadStop: (ctrl, url) {
                    _pullRefresh?.endRefreshing();
                    setState(() {
                      _isLoading = false;
                      _progress  = 100;
                    });
                    // Flush cookies
                    CookieManager.instance().getCookies(url: WebUri(_targetUrl));
                  },

                  onReceivedError: (ctrl, req, err) {
                    if (req.isForMainFrame ?? false) {
                      _pullRefresh?.endRefreshing();
                      setState(() {
                        _isLoading = false;
                        _hasError  = true;
                        _errorMsg  = _resolveError(err.type);
                      });
                    }
                  },

                  shouldOverrideUrlLoading: (ctrl, action) async {
                    final url = action.request.url?.toString() ?? '';

                    // Allow own domain
                    if (url.startsWith('https://tikdown.ddns.net') ||
                        url.startsWith('http://tikdown.ddns.net')) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    // System intents
                    if (url.startsWith('mailto:') || url.startsWith('tel:')) {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) launchUrl(uri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    // External http(s) → confirm
                    if (url.startsWith('http://') || url.startsWith('https://')) {
                      _showOpenExternalDialog(url);
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },

                  onDownloadStartRequest: (ctrl, req) {
                    _handleDownload(
                      url:  req.url.toString(),
                      mime: req.mimeType ?? 'application/octet-stream',
                      contentDisposition: req.contentDisposition,
                    );
                  },

                  onGeolocationPermissionsShowPrompt: (ctrl, origin) async =>
                      GeolocationPermissionShowPromptResponse(
                          origin: origin, allow: false, retain: false),

                  onPermissionRequest: (ctrl, req) async =>
                      PermissionResponse(
                          resources: req.resources,
                          action: PermissionResponseAction.DENY),
                ),
              ),

              // ── Gradient progress bar ─────────────────
              AnimatedOpacity(
                opacity: _isLoading ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _GradientProgressBar(progress: _progress / 100),
                ),
              ),

              // ── Error overlay ─────────────────────────
              if (_hasError)
                AnimatedOpacity(
                  opacity: _hasError ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 350),
                  child: _ErrorView(
                    message: _errorMsg,
                    onRetry: _onRetry,
                  ),
                ),

              // ── Download progress overlay ─────────────
              if (_isDownloading)
                _DownloadOverlay(
                  filename: _dlFilename,
                  progress: _dlProgress,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _handleBackPress() async {
    if (_hasError) {
      setState(() => _hasError = false);
      if (await _isOnline()) {
        _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(_targetUrl)));
      }
      return;
    }

    final canGoBack = await _webViewController?.canGoBack() ?? false;
    if (canGoBack) {
      _webViewController?.goBack();
    } else {
      _showExitDialog();
    }
  }

  void _onRetry() {
    if (!mounted) return;
    setState(() => _hasError = false);
    if (_isOnlineSync()) {
      _webViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(_targetUrl)));
    } else {
      _showError('Van chua co ket noi Internet.');
    }
  }

  void _showError(String msg) {
    setState(() {
      _hasError = true;
      _errorMsg = msg;
      _isLoading = false;
    });
  }

  // ─── Download ──────────────────────────────────────────────────────────────

  Future<void> _handleDownload({
    required String url,
    required String mime,
    String? contentDisposition,
  }) async {
    // 1. Request permission (Android < 10)
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted && !status.isLimited) {
        _showSnack('Can quyen luu tru de tai file!', isError: true);
        return;
      }
    }

    // 2. Extract filename
    String filename = _extractFilename(contentDisposition, url, mime);

    // 3. Determine save path
    String savePath;
    try {
      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          savePath = '${downloadsDir.path}/$filename';
        } else {
          final ext = await getExternalStorageDirectory();
          savePath = '${ext!.path}/$filename';
        }
      } else {
        final docs = await getApplicationDocumentsDirectory();
        savePath = '${docs.path}/$filename';
      }
    } catch (_) {
      final ext = await getExternalStorageDirectory();
      savePath = '${ext!.path}/$filename';
    }

    // 4. Get cookies from WebView
    final cookies = await CookieManager.instance()
        .getCookies(url: WebUri(url));
    final cookieStr =
        cookies.map((c) => '${c.name}=${c.value}').join('; ');

    // 5. Download with Dio
    setState(() {
      _isDownloading = true;
      _dlFilename    = filename;
      _dlProgress    = 0;
    });

    try {
      final dio = Dio();
      if (cookieStr.isNotEmpty) {
        dio.options.headers['Cookie'] = cookieStr;
      }
      dio.options.headers['User-Agent'] =
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/124.0.0.0 Mobile Safari/537.36';

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            setState(() => _dlProgress = received / total);
          }
        },
      );

      setState(() { _isDownloading = false; _dlProgress = 0; });
      _showSnack('Tai xong: $filename');
    } on DioException catch (e) {
      setState(() { _isDownloading = false; _dlProgress = 0; });
      _showSnack('Loi tai: ${e.message}', isError: true);
    }
  }

  String _extractFilename(String? cd, String url, String mime) {
    // Try Content-Disposition header
    if (cd != null && cd.contains('filename=')) {
      final start = cd.indexOf('filename=') + 9;
      var fn = cd.substring(start).replaceAll('"', '').trim();
      if (fn.contains(';')) fn = fn.substring(0, fn.indexOf(';'));
      if (fn.isNotEmpty) return fn;
    }
    // Try URL path
    final uri   = Uri.parse(url);
    final seg   = uri.pathSegments;
    if (seg.isNotEmpty && seg.last.isNotEmpty) return seg.last;
    // Fallback
    final ext = mime.contains('video') ? '.mp4' : '.bin';
    return 'tikdown_${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Thoat ung dung'),
        content: const Text('Ban co muon thoat TikDown khong?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('O lai'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
            child: const Text('Thoat'),
          ),
        ],
      ),
    );
  }

  void _showOpenExternalDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mo lien ket ngoai?'),
        content: Text(
          url.length > 60 ? '${url.substring(0, 60)}...' : url,
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text('Mo'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.accentPink : const Color(0xFF1A1A2E),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: AppTheme.primary,
          onPressed: () {},
        ),
      ),
    );
  }

  // ─── Network ───────────────────────────────────────────────────────────────

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  bool _isOnlineSync() => true; // Optimistic; actual check async

  // ─── Error resolution ──────────────────────────────────────────────────────

  String _resolveError(WebResourceErrorType? type) {
    if (type == WebResourceErrorType.HOST_LOOKUP) {
      return 'Khong tim thay may chu.\nKiem tra ket noi mang.';
    } else if (type == WebResourceErrorType.CONNECT) {
      return 'Khong the ket noi toi may chu.\nMay chu co the dang offline.';
    } else if (type == WebResourceErrorType.TIMEOUT) {
      return 'Ket noi qua thoi gian cho.\nVui long thu lai.';
    } else if (type == WebResourceErrorType.FAILED_SSL_HANDSHAKE) {
      return 'Loi chung chi SSL.\nKhong the ket noi an toan.';
    } else {
      return 'Khong the tai trang.\nKeo xuong de lam moi hoac nhan Thu lai.';
    }
  }
}

// ─── Gradient Progress Bar ────────────────────────────────────────────────────

class _GradientProgressBar extends StatelessWidget {
  final double progress; // 0.0 – 1.0
  const _GradientProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        return SizedBox(
          height: 4,
          width: constraints.maxWidth,
          child: Stack(
            children: [
              // Background
              Container(color: Colors.transparent),
              // Filled portion with gradient + glow
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                height: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF6B35),
                      Color(0xFFFFD000),
                      Color(0xFFFF4757),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x80FF6B35),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppTheme.bgDark : Colors.white,
      child: Stack(
        children: [
          // Top accent bar
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFFD000), Color(0xFFFF4757)],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with glow
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primary.withOpacity(0.15),
                          AppTheme.accentPink.withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: 52,
                      color: AppTheme.primary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Khong the ket noi',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark
                          ? Colors.white60
                          : const Color(0xFF555577),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Gradient retry button
                  GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      width: 170,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF4757)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Thu lai',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Hoac keo xuong de lam moi',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom color dots
          Positioned(
            bottom: 44,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(AppTheme.primary),
                const SizedBox(width: 10),
                _dot(AppTheme.accentYellow),
                const SizedBox(width: 10),
                _dot(AppTheme.accentPink),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 6)],
        ),
      );
}

// ─── Download Overlay ─────────────────────────────────────────────────────────

class _DownloadOverlay extends StatelessWidget {
  final String filename;
  final double progress;
  const _DownloadOverlay({required this.filename, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF4757)],
                    ),
                  ),
                  child: const Icon(Icons.download_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dang tai xuong...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        filename.length > 28
                            ? '${filename.substring(0, 28)}...'
                            : filename,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [
                    Color(0xFFFF6B35),
                    Color(0xFFFFD000),
                    Color(0xFFFF4757),
                  ],
                ).createShader(rect),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white10,
                  color: Colors.white,
                  minHeight: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
