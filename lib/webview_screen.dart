import 'dart:async';
import 'dart:io';
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const String _baseUrl = 'https://tikdown.ddns.net';

  InAppWebViewController? _webCtrl;
  PullToRefreshController? _pullRefresh;

  // UI state
  double  _progress     = 0;
  bool    _isLoading    = true;
  bool    _hasError     = false;
  String  _errorMsg     = '';
  bool    _isServerDown = false; // server down khác mất internet
  bool    _isDownloading = false;
  double  _dlProgress   = 0;
  String  _dlFilename   = '';

  // Hiệu ứng vào màn hình
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<double> _entrySlide;

  // Server ping timer
  Timer? _pingTimer;
  bool   _lastPingOk = true;

  // Tránh setState quá nhiều lần khi load progress
  int _lastProgressUpdate = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupPullRefresh();

    // Entry animation khi vào WebView
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500))..forward();
    _entryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entrySlide = Tween<double>(begin: 30, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    // Ping server mỗi 10s để phát hiện server offline
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pingServer());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entryCtrl.dispose();
    _pingTimer?.cancel();
    super.dispose();
  }

  void _setupPullRefresh() {
    _pullRefresh = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: AppTheme.primary,
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      onRefresh: () async {
        final online = await _checkOnline();
        if (online) {
          _webCtrl?.reload();
        } else {
          _pullRefresh?.endRefreshing();
          _setError('Không có kết nối Internet.');
        }
      },
    );
  }

  // ── Ping server để phát hiện down ─────────────────────────────────────────
  Future<void> _pingServer() async {
    if (!mounted) return;
    final online = await _checkOnline();
    if (!online) return; // Nếu mất internet → lỗi network, không phải server

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final req = await client.headUrl(Uri.parse(_baseUrl));
      final res = await req.close().timeout(const Duration(seconds: 5));
      client.close();
      final ok = res.statusCode < 500;
      if (_lastPingOk != ok || mounted) {
        _lastPingOk = ok;
        if (!ok && mounted) {
          setState(() => _isServerDown = true);
          _showServerBanner();
        } else if (ok && mounted && _isServerDown) {
          setState(() => _isServerDown = false);
          _showSnack('✅ Đã kết nối lại server!');
          _webCtrl?.reload();
        }
      }
    } catch (_) {
      if (_lastPingOk && mounted) {
        _lastPingOk = false;
        setState(() => _isServerDown = true);
        _showServerBanner();
      }
    }
  }

  void _showServerBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showMaterialBanner(MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      backgroundColor: const Color(0xFF2D0A0A),
      leading: const Icon(Icons.cloud_off_rounded, color: Color(0xFFFF4757), size: 28),
      content: const Text(
        '⚠️ Server đã ngắt kết nối',
        style: TextStyle(
          color: Color(0xFFFF8A8A),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            _pingServer();
          },
          child: const Text('Kiểm tra lại',
              style: TextStyle(color: Color(0xFFFF6B35))),
        ),
        TextButton(
          onPressed: () =>
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
          child: const Text('Đóng',
              style: TextStyle(color: Colors.white38)),
        ),
      ],
    ));
  }

  // ── WebView Settings (tối ưu hiệu năng) ───────────────────────────────────
  InAppWebViewSettings _buildSettings() => InAppWebViewSettings(
    javaScriptEnabled: true,
    domStorageEnabled: true,
    databaseEnabled: true,
    useWideViewPort: true,
    loadWithOverviewMode: true,

    supportZoom: false,        // tắt zoom → giảm lag
    builtInZoomControls: false,
    displayZoomControls: false,

    mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
    allowFileAccess: false,
    allowContentAccess: false,
    thirdPartyCookiesEnabled: false,

    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,

    // LOAD_DEFAULT tốt hơn LOAD_CACHE_ELSE_NETWORK cho hiệu năng thực
    cacheMode: CacheMode.LOAD_DEFAULT,

    // Tắt algorithmic darkening để không bị đổi màu theo hệ thống
    algorithmicDarkeningAllowed: false,
    forceDark: ForceDark.OFF,

    // Hiệu năng
    hardwareAcceleration: true,
    overScrollMode: OverScrollMode.NEVER,
    disableHorizontalScroll: false,
    disableVerticalScroll: false,

    // Render priority cao
    rendererPriorityPolicy: RendererPriorityPolicy(
      rendererRequestedPriority: RendererPriority.RENDERER_PRIORITY_IMPORTANT,
      waivedWhenNotVisible: false,
    ),

    userAgent:
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Mobile Safari/537.36',
  );

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entryCtrl,
      builder: (_, child) => Opacity(
        opacity: _entryFade.value,
        child: Transform.translate(
          offset: Offset(0, _entrySlide.value),
          child: child,
        ),
      ),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) => _handleBackPress(),
        child: Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: SafeArea(
            child: Stack(
              children: [
                // ── WebView ───────────────────────────────
                RepaintBoundary(
                  child: AnimatedOpacity(
                    opacity: _hasError ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(_baseUrl)),
                      initialSettings: _buildSettings(),
                      pullToRefreshController: _pullRefresh,

                      onWebViewCreated: (ctrl) => _webCtrl = ctrl,

                      onLoadStart: (ctrl, url) {
                        if (mounted) setState(() {
                          _isLoading = true;
                          _progress  = 5;
                          _hasError  = false;
                        });
                      },

                      // Chỉ setState mỗi 10% để giảm rebuild
                      onProgressChanged: (ctrl, progress) {
                        final rounded = (progress / 10).floor() * 10;
                        if (rounded != _lastProgressUpdate) {
                          _lastProgressUpdate = rounded;
                          if (mounted) setState(() => _progress = progress.toDouble());
                        }
                        if (progress == 100) _pullRefresh?.endRefreshing();
                      },

                      onLoadStop: (ctrl, url) {
                        _pullRefresh?.endRefreshing();
                        if (mounted) setState(() {
                          _isLoading = false;
                          _progress  = 100;
                        });
                        // Ẩn banner server nếu load thành công
                        if (_isServerDown) {
                          ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                          setState(() { _isServerDown = false; _lastPingOk = true; });
                        }
                      },

                      onReceivedError: (ctrl, req, err) {
                        if (!(req.isForMainFrame ?? false)) return;
                        _pullRefresh?.endRefreshing();
                        final msg = _resolveError(err.type);
                        final isServerErr = _isServerError(err.type);
                        if (mounted) setState(() {
                          _isLoading    = false;
                          _hasError     = true;
                          _isServerDown = isServerErr;
                          _errorMsg     = msg;
                        });
                        if (isServerErr) _showServerBanner();
                      },

                      shouldOverrideUrlLoading: (ctrl, action) async {
                        final url = action.request.url?.toString() ?? '';
                        if (url.startsWith(_baseUrl) ||
                            url.startsWith('http://tikdown.ddns.net')) {
                          return NavigationActionPolicy.ALLOW;
                        }
                        if (url.startsWith('mailto:') || url.startsWith('tel:')) {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) launchUrl(uri);
                          return NavigationActionPolicy.CANCEL;
                        }
                        if (url.startsWith('http://') || url.startsWith('https://')) {
                          _showOpenExternalDialog(url);
                          return NavigationActionPolicy.CANCEL;
                        }
                        return NavigationActionPolicy.ALLOW;
                      },

                      onDownloadStartRequest: (ctrl, req) => _handleDownload(
                        url:  req.url.toString(),
                        mime: req.mimeType ?? 'application/octet-stream',
                        contentDisposition: req.contentDisposition,
                      ),

                      onGeolocationPermissionsShowPrompt: (ctrl, origin) async =>
                          GeolocationPermissionShowPromptResponse(
                              origin: origin, allow: false, retain: false),

                      onPermissionRequest: (ctrl, req) async =>
                          PermissionResponse(
                              resources: req.resources,
                              action: PermissionResponseAction.DENY),
                    ),
                  ),
                ),

                // ── Progress bar ──────────────────────────
                AnimatedOpacity(
                  opacity: _isLoading ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _GradientProgressBar(progress: _progress / 100),
                  ),
                ),

                // ── Error overlay ─────────────────────────
                if (_hasError)
                  _ErrorView(
                    message: _errorMsg,
                    isServerDown: _isServerDown,
                    onRetry: _onRetry,
                  ),

                // ── Download overlay ──────────────────────
                if (_isDownloading)
                  _DownloadOverlay(
                    filename: _dlFilename,
                    progress: _dlProgress,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _handleBackPress() async {
    if (_hasError) {
      setState(() => _hasError = false);
      if (await _checkOnline()) {
        _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(_baseUrl)));
      }
      return;
    }
    final canGoBack = await _webCtrl?.canGoBack() ?? false;
    if (canGoBack) {
      _webCtrl?.goBack();
    } else {
      _showExitDialog();
    }
  }

  void _onRetry() {
    if (!mounted) return;
    setState(() => _hasError = false);
    _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(_baseUrl)));
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() { _hasError = true; _errorMsg = msg; _isLoading = false; });
  }

  // ── Download ──────────────────────────────────────────────────────────────

  Future<void> _handleDownload({
    required String url,
    required String mime,
    String? contentDisposition,
  }) async {
    // Kiểm tra quyền (nhắc lại nếu user từ chối lần đầu)
    if (Platform.isAndroid) {
      final ver = await _androidVersion();
      Permission perm = ver >= 33 ? Permission.videos : Permission.storage;
      var status = await perm.status;
      if (!status.isGranted) {
        status = await perm.request();
        if (!status.isGranted) {
          _showSnack('❌ Cần quyền lưu trữ để tải file!', isError: true);
          if (status.isPermanentlyDenied) openAppSettings();
          return;
        }
      }
    }

    final filename = _extractFilename(contentDisposition, url, mime);

    String savePath;
    try {
      if (Platform.isAndroid) {
        final dl = Directory('/storage/emulated/0/Download');
        savePath = '${(await dl.exists() ? dl : await getExternalStorageDirectory())!.path}/$filename';
      } else {
        savePath = '${(await getApplicationDocumentsDirectory()).path}/$filename';
      }
    } catch (_) {
      savePath = '${(await getExternalStorageDirectory())!.path}/$filename';
    }

    final cookies = await CookieManager.instance().getCookies(url: WebUri(url));
    final cookieStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');

    setState(() { _isDownloading = true; _dlFilename = filename; _dlProgress = 0; });

    try {
      final dio = Dio();
      if (cookieStr.isNotEmpty) dio.options.headers['Cookie'] = cookieStr;
      dio.options.headers['User-Agent'] =
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/124.0.0.0';

      await dio.download(url, savePath,
          onReceiveProgress: (rec, total) {
            if (total > 0 && mounted) setState(() => _dlProgress = rec / total);
          });

      if (mounted) setState(() { _isDownloading = false; _dlProgress = 0; });
      _showSnack('✅ Tải xong: $filename');
    } on DioException catch (e) {
      if (mounted) setState(() { _isDownloading = false; _dlProgress = 0; });
      _showSnack('❌ Lỗi tải: ${e.message}', isError: true);
    }
  }

  String _extractFilename(String? cd, String url, String mime) {
    if (cd != null && cd.contains('filename=')) {
      var fn = cd.substring(cd.indexOf('filename=') + 9).replaceAll('"', '').trim();
      if (fn.contains(';')) fn = fn.substring(0, fn.indexOf(';'));
      if (fn.isNotEmpty) return fn;
    }
    final seg = Uri.parse(url).pathSegments;
    if (seg.isNotEmpty && seg.last.isNotEmpty) return seg.last;
    return 'tikdown_${DateTime.now().millisecondsSinceEpoch}${mime.contains('video') ? '.mp4' : '.bin'}';
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Thoát ứng dụng',
            style: TextStyle(color: Colors.white)),
        content: const Text('Bạn có muốn thoát TikDown không?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Ở lại', style: TextStyle(color: AppTheme.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentPink),
            onPressed: () { Navigator.pop(context); SystemNavigator.pop(); },
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
  }

  void _showOpenExternalDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mở liên kết ngoài?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          url.length > 60 ? '${url.substring(0, 60)}...' : url,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: const Text('Mở'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.accentPink : const Color(0xFF1A1A2E),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool> _checkOnline() async {
    final r = await Connectivity().checkConnectivity();
    return r != ConnectivityResult.none;
  }

  Future<int> _androidVersion() async {
    try {
      final m = RegExp(r'Android (\d+)').firstMatch(Platform.operatingSystemVersion);
      if (m != null) return int.parse(m.group(1)!);
    } catch (_) {}
    return 0;
  }

  bool _isServerError(WebResourceErrorType? type) {
    if (type == null) return false;
    return type == WebResourceErrorType.CONNECT ||
        type == WebResourceErrorType.HOST_LOOKUP ||
        type == WebResourceErrorType.FAILED_SSL_HANDSHAKE ||
        type == WebResourceErrorType.TIMEOUT;
  }

  String _resolveError(WebResourceErrorType? type) {
    if (type == WebResourceErrorType.HOST_LOOKUP) {
      return 'Không tìm thấy máy chủ.\nKiểm tra kết nối mạng.';
    } else if (type == WebResourceErrorType.CONNECT) {
      return 'Server đã ngắt kết nối.\nVui long thử lại sau.';
    } else if (type == WebResourceErrorType.TIMEOUT) {
      return 'Kết nối quá thời gian chờ.\nVui lòng thử lại.';
    } else if (type == WebResourceErrorType.FAILED_SSL_HANDSHAKE) {
      return 'Lỗi chứng chỉ SSL.\nKhông thể kết nối an toàn.';
    } else {
      return 'Không thể tải trang.\nKéo xuống để làm mới hoặc nhấn Thử lại.';
    }
  }
}

// ─── Gradient Progress Bar ────────────────────────────────────────────────────
class _GradientProgressBar extends StatelessWidget {
  final double progress;
  const _GradientProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => SizedBox(
          height: 3,
          width: c.maxWidth,
          child: Stack(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: c.maxWidth * progress.clamp(0.0, 1.0),
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFFD000), Color(0xFFFF4757)]),
                boxShadow: [BoxShadow(
                    color: Color(0x80FF6B35), blurRadius: 6, spreadRadius: 1)],
              ),
            ),
          ]),
        ),
      );
}

// ─── Error View ───────────────────────────────────────────────────────────────
class _ErrorView extends StatefulWidget {
  final String message;
  final bool isServerDown;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.isServerDown, required this.onRetry});
  @override
  State<_ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends State<_ErrorView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _fade.value,
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: Container(
        color: AppTheme.bgDark,
        child: Stack(children: [
          // Top gradient bar
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFFD000), Color(0xFFFF4757)]),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Icon
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      (widget.isServerDown ? AppTheme.accentPink : AppTheme.primary)
                          .withOpacity(0.18),
                      Colors.transparent,
                    ]),
                  ),
                  child: Icon(
                    widget.isServerDown
                        ? Icons.cloud_off_rounded
                        : Icons.wifi_off_rounded,
                    size: 58,
                    color: (widget.isServerDown
                        ? AppTheme.accentPink
                        : AppTheme.primary)
                        .withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  widget.isServerDown ? 'Server ngắt kết nối' : 'Không thể kết nối',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14, height: 1.6, color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 32),
                // Retry button
                GestureDetector(
                  onTap: widget.onRetry,
                  child: Container(
                    width: 180, height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        colors: widget.isServerDown
                            ? [const Color(0xFFFF4757), const Color(0xFFFF6B9D)]
                            : [const Color(0xFFFF6B35), const Color(0xFFFF4757)],
                      ),
                      boxShadow: [BoxShadow(
                        color: AppTheme.primary.withOpacity(0.45),
                        blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 4),
                      )],
                    ),
                    child: const Center(
                      child: Text('Thử lại',
                          style: TextStyle(
                              color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Hoặc kéo xuống để làm mới',
                    style: TextStyle(fontSize: 12, color: Colors.white24)),
              ]),
            ),
          ),
          // Bottom dots
          Positioned(
            bottom: 44, left: 0, right: 0,
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
        ]),
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: c, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: c.withOpacity(0.6), blurRadius: 6)],
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
      bottom: 20, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 24, spreadRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF4757)]),
                ),
                child: const Icon(Icons.download_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Đang tải xuống...',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Text(
                    filename.length > 28 ? '${filename.substring(0, 28)}...' : filename,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              )),
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Color(0xFFFF6B35),
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFFD000), Color(0xFFFF4757)],
                ).createShader(r),
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
