import 'package:flutter/material.dart';
import 'home_palette.dart';

/// Temporary destination for home menus whose screens are not built yet.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.message,
    required this.palette,
  });

  final String title;
  final String message;
  final HomePalette palette;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: palette.background,
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 48,
                fontWeight: FontWeight.w600,
                color: palette.title,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 28,
                color: palette.description,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              height: 96,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.start,
                  foregroundColor: palette.onStart,
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 40),
                label: const Text('홈으로'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
