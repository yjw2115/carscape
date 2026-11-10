import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'features/tutorial/presentation/tutorial_screen.dart';
import 'features/tutorial/presentation/tutorial_style.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(const CarscapePreview());
}

/// Standalone entry after theme selection. The team's home/entry feature can
/// push TutorialScreen directly without using this preview application.
class CarscapePreview extends StatelessWidget {
  const CarscapePreview({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Carscape · 얼어붙은 밤',
    debugShowCheckedModeBanner: false,
    theme: tutorialTheme(),
    home: const TutorialScreen(),
  );
}
