import 'package:flutter/material.dart';
import 'device_catalog.dart';
import 'fake_vehicle_service.dart';
import 'vehicle_service.dart';

/// Dev-only button that stands in for the car's physical buttons. Renders
/// nothing unless [vehicle] is a [FakeVehicleService].
class FakeVehicleButton extends StatelessWidget {
  const FakeVehicleButton(this.vehicle, {super.key});
  final VehicleService vehicle;

  @override
  Widget build(BuildContext context) {
    final fake = vehicle;
    if (fake is! FakeVehicleService) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () =>
          showDialog<void>(context: context, builder: (_) => _FakePanel(fake)),
      icon: const Icon(Icons.build_outlined, size: 18),
      label: const Text('가짜 차량'),
    );
  }
}

class _FakePanel extends StatefulWidget {
  const _FakePanel(this.car);
  final FakeVehicleService car;

  @override
  State<_FakePanel> createState() => _FakePanelState();
}

class _FakePanelState extends State<_FakePanel> {
  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    final parked = car.value(DeviceId.gear) == gearPark;
    return AlertDialog(
      title: const Text('가짜 차량 (개발용)'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            SwitchListTile(
              title: const Text('기어 P단'),
              value: parked,
              onChanged: (v) =>
                  setState(() => car.set(DeviceId.gear, v ? gearPark : 0)),
            ),
            const Divider(),
            for (final id in DeviceId.values)
              if (id != DeviceId.gear)
                ListTile(
                  dense: true,
                  title: Text(id.label),
                  subtitle: Text(
                    car.unsupported.contains(id)
                        ? '미지원'
                        : '값 ${car.value(id)}${id.perSeat ? ' (운전석)' : ''}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => setState(
                          () => car.unsupported.contains(id)
                              ? car.unsupported.remove(id)
                              : car.unsupported.add(id),
                        ),
                        child: Text(
                          car.unsupported.contains(id) ? '지원' : '미지원',
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => setState(
                          () => car.set(id, car.value(id) == 0 ? 1 : 0),
                        ),
                        child: const Text('조작'),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
