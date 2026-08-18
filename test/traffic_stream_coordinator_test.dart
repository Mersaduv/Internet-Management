import 'package:flutter_test/flutter_test.dart';
import 'package:Ariyabod/models/client_traffic_rate.dart';
import 'package:Ariyabod/services/traffic_stream_coordinator.dart';

void main() {
  test('stream coordinator delivers one sample to listener', () async {
    final samples = <Map<String, ClientTrafficRate>>[];
    final coordinator = TrafficStreamCoordinator(
      onSample: () async => {
        '192.168.1.10': ClientTrafficRate(
          rxBps: 1000,
          txBps: 500,
          sampledAt: DateTime.now(),
        ),
      },
      onRates: samples.add,
      shouldContinue: () => samples.isEmpty,
      intervalFor: (_, __) => Duration.zero,
    );

    coordinator.start();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    coordinator.stop();

    expect(samples, hasLength(1));
    expect(samples.first['192.168.1.10']?.rxBps, 1000);
  });
}
