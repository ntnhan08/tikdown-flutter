import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'splash_screen.dart';
import 'app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(false);
  }

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Cố định dark UI - không bị ảnh hưởng light/dark mode hệ thống
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF0D0D1A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Xin quyền tải xuống ngay khi khởi động app
  await _requestDownloadPermissions();

  runApp(const TikDownApp());
}

Future<void> _requestDownloadPermissions() async {
  if (!Platform.isAndroid) return;
  final ver = await _androidVersion();
  if (ver >= 33) {
    await [Permission.videos, Permission.photos, Permission.notification].request();
  } else {
    await [Permission.storage].request();
  }
}

Future<int> _androidVersion() async {
  try {
    final m = RegExp(r'Android (\d+)').firstMatch(Platform.operatingSystemVersion);
    if (m != null) return int.parse(m.group(1)!);
  } catch (_) {}
  return 0;
}

class TikDownApp extends StatelessWidget {
  const TikDownApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TikDown',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark, // Luôn dark, không theo hệ thống
      home: const SplashScreen(),
    );
  }
}
