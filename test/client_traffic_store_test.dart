import 'package:flutter_test/flutter_test.dart';
import 'package:abar_tawseeh_ict/models/client_info.dart';
import 'package:abar_tawseeh_ict/models/client_traffic_rate.dart';
import 'package:abar_tawseeh_ict/services/client_traffic_store.dart';

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

  test('applyPoll skips unmeasured IPs when sample is missing', () {
    final store = ClientTrafficStore();
    final changed = store.applyPoll(
      trackedIps: {'172.16.0.20'},
      samples: const {},
      rateChanged: (_, __) => true,
    );

    expect(changed, isFalse);
    expect(store.isMeasured('172.16.0.20'), isFalse);
    expect(store.rateFor('172.16.0.20'), isNull);
  });

  test('applyPoll stores real zero rates after warmup polls', () {
    final store = ClientTrafficStore();
    store.applyPoll(
      trackedIps: {'172.16.0.20'},
      samples: {
        '172.16.0.20': ClientTrafficRate(
          rxBps: 0,
          txBps: 0,
          sampledAt: DateTime.now(),
        ),
      },
      rateChanged: (_, __) => true,
    );
    expect(store.isMeasured('172.16.0.20'), isFalse);

    final changed = store.applyPoll(
      trackedIps: {'172.16.0.20'},
      samples: {
        '172.16.0.20': ClientTrafficRate(
          rxBps: 0,
          txBps: 0,
          sampledAt: DateTime.now(),
        ),
      },
      rateChanged: (_, __) => true,
    );

    expect(changed, isTrue);
    expect(store.isMeasured('172.16.0.20'), isTrue);
    expect(store.rateFor('172.16.0.20')?.rxBps, 0);
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

  test('applyPoll stores raw sample without blending', () {
    final store = ClientTrafficStore();
    store.onViewportChanged({'172.16.0.20'});
    store.applyPoll(
      trackedIps: {'172.16.0.20'},
      samples: {
        '172.16.0.20': ClientTrafficRate(
          rxBps: 1000000,
          txBps: 300000,
          sampledAt: DateTime.now(),
        ),
      },
      rateChanged: (_, __) => true,
    );

    store.applyPoll(
      trackedIps: {'172.16.0.20'},
      samples: {
        '172.16.0.20': ClientTrafficRate(
          rxBps: 200000,
          txBps: 50000,
          sampledAt: DateTime.now(),
        ),
      },
      rateChanged: (_, __) => true,
    );

    expect(store.rateFor('172.16.0.20')!.rxBps, 1000000);
    expect(store.syncDisplayTick(), isTrue);
    expect(store.rateFor('172.16.0.20')!.rxBps, 200000);
  });

  test('syncDisplayTick publishes on one-second cadence only when changed', () {
    final store = ClientTrafficStore();
    store.onViewportChanged({'172.16.0.20'});
    store.applyPoll(
      trackedIps: {'172.16.0.20'},
      samples: {
        '172.16.0.20': ClientTrafficRate(
          rxBps: 500000,
          txBps: 100000,
          sampledAt: DateTime.now(),
        ),
      },
      rateChanged: (_, __) => true,
    );

    expect(store.syncDisplayTick(), isFalse);
    store.applyPoll(
      trackedIps: {'172.16.0.20'},
      samples: {
        '172.16.0.20': ClientTrafficRate(
          rxBps: 500000,
          txBps: 100000,
          sampledAt: DateTime.now(),
        ),
      },
      rateChanged: (_, __) => true,
    );
    expect(store.syncDisplayTick(), isFalse);
  });

  test('onViewportChanged keeps last rate briefly after leave', () {
    final store = ClientTrafficStore();
    store.onViewportChanged({'172.16.0.20'});
    store.applyPoll(
      trackedIps: {'172.16.0.20'},
      samples: {
        '172.16.0.20': ClientTrafficRate(
          rxBps: 500,
          txBps: 100,
          sampledAt: DateTime.now(),
        ),
      },
      rateChanged: (_, __) => true,
    );
    expect(store.isMeasured('172.16.0.20'), isTrue);

    store.onViewportChanged({'172.16.0.99'});

    expect(store.isMeasured('172.16.0.20'), isTrue);
    expect(store.rateFor('172.16.0.20')?.rxBps, 500);
    expect(store.isMeasured('172.16.0.99'), isFalse);
  });

  test('onViewportChanged drops retained rates after retainAfterLeave', () {
    final store = ClientTrafficStore()..retainAfterLeave = Duration.zero;
    store.onViewportChanged({'172.16.0.20'});
    store.applyPoll(
      trackedIps: {'172.16.0.20'},
      samples: {
        '172.16.0.20': ClientTrafficRate(
          rxBps: 500,
          txBps: 100,
          sampledAt: DateTime.now(),
        ),
      },
      rateChanged: (_, __) => true,
    );

    store.onViewportChanged({'172.16.0.99'});

    expect(store.isMeasured('172.16.0.20'), isFalse);
    expect(store.rateFor('172.16.0.20'), isNull);
  });

  test('awaitingFirstSampleTimedOut after placeholderTimeout', () {
    final store = ClientTrafficStore()
      ..placeholderTimeout = const Duration(seconds: 3);
    final start = DateTime(2026, 1, 1, 12);
    store.onViewportChanged({'172.16.0.20'}, now: start);

    expect(
      store.awaitingFirstSampleTimedOut('172.16.0.20', now: start),
      isFalse,
    );
    expect(
      store.awaitingFirstSampleTimedOut(
        '172.16.0.20',
        now: start.add(const Duration(seconds: 3)),
      ),
      isTrue,
    );
  });
}
