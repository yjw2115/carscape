import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../vehicle/fake_vehicle_panel.dart';
import '../../vehicle/vehicle_service.dart';

/// Left: content + buttons at the bottom-left (driver side).
/// Right: information. Narrow widths stack everything in one scroll.
class EntryLayout extends StatelessWidget {
  const EntryLayout({
    super.key,
    required this.vehicle,
    required this.content,
    required this.actions,
    required this.side,
    this.sideWidth = 360,
    this.overlay,
    this.background,
  });

  final VehicleService vehicle;
  final List<Widget> content;
  final List<Widget> actions;
  final Widget side;
  final double sideWidth;
  final Widget? overlay;
  final Gradient? background;

  @override
  Widget build(BuildContext context) {
    final buttons = Wrap(spacing: 10, runSpacing: 10, children: actions);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: background),
        child: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, c) {
                  if (c.maxWidth < 740) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ..._gap(content),
                        const SizedBox(height: 20),
                        buttons,
                        const SizedBox(height: 20),
                        side,
                      ],
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(36, 30, 36, 28),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: _gap(content),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              buttons,
                            ],
                          ),
                        ),
                        const SizedBox(width: 28),
                        SizedBox(width: sideWidth, child: side),
                      ],
                    ),
                  );
                },
              ),
            ),
            ?overlay,
            Positioned(top: 4, right: 4, child: FakeVehicleButton(vehicle)),
          ],
        ),
      ),
    );
  }

  static List<Widget> _gap(List<Widget> items) => [
    for (final (i, w) in items.indexed) ...[
      if (i > 0) const SizedBox(height: 14),
      w,
    ],
  ];
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = AppColors.panel,
    this.border = AppColors.border,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final Color color;
  final Color border;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border),
    ),
    child: child,
  );
}

class Callout extends StatelessWidget {
  const Callout(this.text, {super.key, this.warn = false});
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    color: warn ? const Color(0xFF1F1A10) : AppColors.panel,
    border: warn ? const Color(0xFF5A4220) : AppColors.border,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          warn ? Icons.warning_amber_rounded : Icons.info_outline,
          size: 18,
          color: AppColors.amber,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFFCFCBC2)),
          ),
        ),
      ],
    ),
  );
}
