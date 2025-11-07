import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Màu sắc
  static const Color backgroundColor = Color(0xFFEAF7FF);
  static const Color textColor = Color(0xFF1F365C);

  // Kích thước & khoảng cách
  static const double fontSize = 18.0;
  static const double logoMaxWidth = 343.0;
  static const double logoMaxHeight = 187.0;
  static const double horizontalPadding = 32.0;
  static const double logoTextSpacing = 20.0;

  // Animation state
  int _dotCount = 0;
  Timer? _dotTimer;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _startDotAnimation();
    _startNavigationTimer();
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    _navigationTimer?.cancel();
    super.dispose();
  }

  /// Bắt đầu animation chấm nhấp nháy
  /// Chu kỳ: 0 chấm → 1 chấm → 2 chấm → 3 chấm → lặp lại
  /// Mỗi bước ~300ms, tổng chu kỳ ~900ms
  void _startDotAnimation() {
    _dotTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      setState(() {
        _dotCount = (_dotCount + 1) % 4; // 0, 1, 2, 3, 0, 1, 2, 3...
      });
    });
  }

  /// Điều hướng sang HomePage sau 2.5 giây
  void _startNavigationTimer() {
    _navigationTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  /// Tạo chuỗi chấm dựa trên _dotCount
  String _buildDots() {
    if (_dotCount == 0) return '';
    return ' .' * _dotCount;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Tính toán kích thước logo responsive
    final logoWidth = (0.8 * screenWidth).clamp(0.0, logoMaxWidth);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Ellipse 15
                Container(
                  width: logoWidth,
                  height: logoWidth, // Hình tròn nên width = height
                  constraints: BoxConstraints(
                    maxWidth: logoMaxWidth,
                    maxHeight: logoMaxHeight,
                  ),
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/ellipse15.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: logoTextSpacing),

                // Text "Đang tải . . ." với animation
                SizedBox(
                  height: 30, // Chiều cao cố định để tránh layout shift
                  child: Center(
                    child: Text(
                      'Đang tải${_buildDots()}',
                      style: const TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
