import 'package:flutter_test/flutter_test.dart';
import 'package:Ariyabod/models/client_info.dart';
import 'package:Ariyabod/models/client_traffic_rate.dart';
import 'package:Ariyabod/services/client_traffic_store.dart';

void main() {
  test('tracking includes pending dynamic leases in display list', () {
    final store = ClientTrafficStore();
    final clients = [
      ClientInfo(
        type: 'dhcp',
        source: 'dhcp_lease',
        ipAddress: '172.16.0.20',
        macAddress: 'AA:BB:CC:DD:EE:20',
        isStaticLease: false,
        rawData: const {'dynamic': 'true'},
      ),
      ClientInfo(
        type: 'dhcp',
        source: 'dhcp_lease',
        ipAddress: '172.16.0.21',
        macAddress: 'AA:BB:CC:DD:EE:21',
        isStaticLease: true,
        rawData: const {'dynamic': 'false'},
      ),
    ];

    final tracking = store.trackingContext(clients);
    expect(tracking.ips, containsAll(['172.16.0.20', '172.16.0.21']));
    expect(tracking.macToIp['AA:BB:CC:DD:EE:20'], '172.16.0.20');
  });

  test('applyPoll marks each tracked IP measured with zero fallback', () {
    final store = ClientTrafficStore();
    final changed = store.applyPoll(
      trackedIps: {'172.16.0.20'},
      samples: const {},
      rateChanged: (_, __) => true,
    );

    expect(changed, isTrue);
    expect(store.isMeasured('172.16.0.20'), isTrue);
    expect(store.rateFor('172.16.0.20')?.rxBps, 0);
    expect(store.rateFor('172.16.0.20')?.txBps, 0);
  });

  test('newIpsSinceLastPoll detects newly joined pending device', () {
    final store = ClientTrafficStore();
    store.applyPoll(
      trackedIps: {'172.16.0.20'},
      samples: {
        '172.16.0.20': ClientTrafficRate(
          rxBps: 100,
          txBps: 50,
          sampledAt: DateTime.now(),
        ),
      },
      rateChanged: (_, __) => true,
    );

    expect(
      store.newIpsSinceLastPoll({'172.16.0.20', '172.16.0.99'}),
      {'172.16.0.99'},
    );
  });
}
