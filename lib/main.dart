import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/tutorial/presentation/tutorial_style.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(const CarscapePreview());
}

/// App entry. Starts on the home screen, which pushes the tutorial and other
/// features. The tutorial keeps its own dark theme from [tutorialTheme].
class CarscapePreview extends StatelessWidget {
  const CarscapePreview({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Carscape',
    debugShowCheckedModeBanner: false,
    theme: tutorialTheme(),
    home: const HomeScreen(),
  );
}
