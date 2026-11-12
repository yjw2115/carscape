import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../features/home/presentation/home_palette.dart';
import '../features/home/presentation/home_screen.dart';

typedef RailPageBuilder<T> = T Function(double s, HomePalette palette);

/// Page opened from the home, in the home's look: a driver-side rail
/// (page buttons on top, a back button at the bottom) and content on the
/// right. Sizes scale from [homeReferenceSize] like the home screen.
class RailPage extends StatelessWidget {
  const RailPage({
    super.key,
    required this.title,
    required this.body,
    this.rail,
    this.backLabel = '홈으로',
    this.onBack,
    this.overlay,
  });

  final String title;
  final RailPageBuilder<Widget> body;
  final RailPageBuilder<List<Widget>>? rail;

  /// Null hides the back button.
  final String? backLabel;

  /// Defaults to closing the page.
  final VoidCallback? onBack;

  /// Stacked over the whole page, e.g. a dialog-like panel.
  final RailPageBuilder<List<Widget>>? overlay;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final p = HomePalette.of(brightness);
    return Theme(
      data: homeTheme(brightness),
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final s = math.min(
                c.maxWidth / homeReferenceSize.width,
                c.maxHeight / homeReferenceSize.height,
              );
              return Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(32 * s),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 252 * s,
                          padding: EdgeInsets.all(24 * s),
                          decoration: BoxDecoration(
                            color: p.rail,
                            borderRadius: BorderRadius.circular(36 * s),
                            border: Border.all(
                              color: p.railBorder,
                              width: 1.5 * s,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final (i, w)
                                  in (rail?.call(s, p) ?? []).indexed)
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: i == 0 ? 0 : 16 * s,
                                  ),
                                  child: w,
                                ),
                              const Spacer(),
                              if (backLabel != null)
                                RailAction(
                                  s: s,
                                  palette: p,
                                  icon: Icons.arrow_back_rounded,
                                  label: backLabel!,
                                  onTap:
                                      onBack ??
                                      () => Navigator.of(context).maybePop(),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 48 * s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 24 * s),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 64 * s,
                                  fontWeight: FontWeight.w600,
                                  color: p.title,
                                ),
                              ),
                              SizedBox(height: 32 * s),
                              Expanded(child: body(s, p)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...?overlay?.call(s, p),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Rail button in the home's style. [primary] is the sand accent; a null
/// [onTap] shows it disabled.
class RailAction extends StatelessWidget {
  const RailAction({
    super.key,
    required this.s,
    required this.palette,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
    this.height = 176,
  });

  final double s;
  final HomePalette palette;
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Sand stands out on the blue rail in both light and dark.
    final fg = primary ? HyundaiColors.blue : palette.onButton;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: SizedBox(
          height: height * s,
          child: Material(
            color: primary ? HyundaiColors.sand : palette.button,
            borderRadius: BorderRadius.circular(26 * s),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8 * s),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 58 * s, color: fg),
                      SizedBox(height: 14 * s),
                    ],
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30 * s,
                        fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Korean text wraps between any two letters. Gluing each word's letters
/// with a word joiner (U+2060) makes lines break only at spaces.
String keepWords(String text) =>
    text.split(' ').map((w) => w.split('').join('⁠')).join(' ');

/// Rounded content card in the home's card colors.
class RailCard extends StatelessWidget {
  const RailCard({
    super.key,
    required this.s,
    required this.palette,
    required this.child,
    this.highlight = false,
  });

  final double s;
  final HomePalette palette;
  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 36 * s, vertical: 28 * s),
    decoration: BoxDecoration(
      color: palette.card,
      borderRadius: BorderRadius.circular(28 * s),
      border: Border.all(
        color: highlight ? palette.selectedBorder : palette.cardBorder,
        width: (highlight ? 3 : 1.5) * s,
      ),
    ),
    child: child,
  );
}

enum ChipTone { neutral, ok, warning }

/// A word or two of status in a pill (완료, 점검 전 …), used instead of a
/// sentence of gray text.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.s,
    required this.palette,
    required this.label,
    this.tone = ChipTone.neutral,
    this.icon,
  });

  final double s;
  final HomePalette palette;
  final String label;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    // Active Blue is too light for text on the light theme's white cards.
    final ok = p == HomePalette.dark
        ? HyundaiColors.activeBlue
        : HyundaiColors.blue;
    final (fg, bg) = switch (tone) {
      ChipTone.ok => (ok, HyundaiColors.activeBlue.withValues(alpha: 0.16)),
      ChipTone.warning => (p.onWarning, p.warning),
      ChipTone.neutral => (p.title, p.checking),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 12 * s),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(40 * s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 30 * s, color: fg),
            SizedBox(width: 10 * s),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 28 * s,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
