import 'package:flutter/material.dart';
import 'home_palette.dart';

/// Floating control panel on the driver side. [s] scales design pixels.
class HomeRail extends StatelessWidget {
  const HomeRail({
    super.key,
    required this.s,
    required this.palette,
    required this.onTutorial,
    required this.onRecords,
    required this.onSettings,
    required this.onVehicleCheck,
    required this.onPrevious,
    required this.onNext,
  });

  final double s;
  final HomePalette palette;
  final VoidCallback onTutorial;
  final VoidCallback onRecords;
  final VoidCallback onSettings;
  final VoidCallback onVehicleCheck;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      width: 252 * s,
      padding: EdgeInsets.all(24 * s),
      decoration: BoxDecoration(
        color: p.rail,
        borderRadius: BorderRadius.circular(36 * s),
        border: Border.all(color: p.railBorder, width: 1.5 * s),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 60 * s,
            offset: Offset(0, 24 * s),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MenuButton(
            s: s,
            palette: p,
            icon: Icons.menu_book_outlined,
            label: '튜토리얼',
            onTap: onTutorial,
          ),
          SizedBox(height: 16 * s),
          _MenuButton(
            s: s,
            palette: p,
            icon: Icons.emoji_events_outlined,
            label: '기록·순위',
            onTap: onRecords,
          ),
          SizedBox(height: 16 * s),
          Row(
            children: [
              Expanded(
                child: _MenuButton(
                  s: s,
                  palette: p,
                  icon: Icons.settings_outlined,
                  label: '설정',
                  onTap: onSettings,
                ),
              ),
              SizedBox(width: 16 * s),
              // Re-run the vehicle check (e.g. after a software update).
              // It also runs on its own before the tutorial.
              Expanded(
                child: SizedBox(
                  height: 176 * s,
                  child: _RailTile(
                    s: s,
                    palette: p,
                    label: '차량 점검',
                    onTap: onVehicleCheck,
                    child: Icon(
                      Icons.build_outlined,
                      size: 58 * s,
                      color: p.onButton,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '테마 선택',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28 * s,
              fontWeight: FontWeight.w500,
              color: p.railLabel,
            ),
          ),
          SizedBox(height: 22 * s),
          SizedBox(
            height: 150 * s,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _RailTile(
                    s: s,
                    palette: p,
                    label: '이전 테마',
                    onTap: onPrevious,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 72 * s,
                      color: p.onButton,
                    ),
                  ),
                ),
                SizedBox(width: 16 * s),
                Expanded(
                  child: _RailTile(
                    s: s,
                    palette: p,
                    label: '다음 테마',
                    onTap: onNext,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 72 * s,
                      color: p.onButton,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.s,
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final double s;
  final HomePalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 176 * s,
    child: _RailTile(
      s: s,
      palette: palette,
      label: label,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 58 * s, color: palette.onButton),
          SizedBox(height: 14 * s),
          Text(
            label,
            style: TextStyle(
              fontSize: 32 * s,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.3 * s,
              color: palette.onButton,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.s,
    required this.palette,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final double s;
  final HomePalette palette;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: palette.button,
      borderRadius: BorderRadius.circular(26 * s),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(child: child),
      ),
    ),
  );
}
