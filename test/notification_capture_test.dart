import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_ai/platform/notification_capture.dart';
import 'package:spendwise_ai/presentation/tracking/capture_controller.dart';
import 'package:spendwise_ai/presentation/app_theme.dart';
import 'package:spendwise_ai/presentation/tracking/tracking_screens.dart';

class FakeCaptureClient implements NotificationCaptureClient {
  @override
  bool supported = true;
  bool enabled = false;
  bool granted = false;
  bool connected = false;
  bool fail = false;
  int days = 1;
  List<String> packages = [];
  int reads = 0;
  int updates = 0;
  final signal = StreamController<void>.broadcast();
  Map<String, Object?>? raw = {
    'title': 'Synthetic title',
    'body': 'Synthetic confidential fixture',
  };
  Completer<Map<String, Object?>?>? delayedContent;
  @override
  Stream<void> get changes => signal.stream;
  @override
  Future<CaptureSnapshot> snapshot() async {
    reads++;
    if (fail) throw StateError('Synthetic storage failure');
    return CaptureSnapshot(
      enabled: enabled,
      permissionGranted: granted,
      listenerConnected: connected,
      retentionDays: days,
      packages: packages,
      sources: const [
        CaptureSource('my.com.tngdigital.ewallet', "Touch 'n Go eWallet"),
      ],
    );
  }

  @override
  Future<void> configure(
    bool enabled,
    List<String> packages,
    int retentionDays,
  ) async {
    updates++;
    if (fail) throw StateError('Synthetic storage failure');
    this.enabled = enabled;
    this.packages = packages;
    days = retentionDays;
  }

  @override
  Future<List<CaptureEvent>> history({int? before}) async => before == null
      ? [
          CaptureEvent(
            sequence: 1,
            eventId: 'synthetic-reference',
            packageName: 'my.com.tngdigital.ewallet',
            postedAt: DateTime.utc(2026, 1, 1),
            capturedAt: DateTime.utc(2026, 1, 1),
            notificationId: 42,
            deliveries: 1,
            status: 'captured',
            contentState: raw == null ? 'deleted' : 'retained',
          ),
        ]
      : [];
  @override
  Future<Map<String, Object?>?> content(String eventId) async =>
      delayedContent == null ? raw : delayedContent!.future;
  @override
  Future<void> eraseContent({String? eventId}) async {
    raw = null;
  }

  @override
  Future<void> openAccessSettings() async {}
  @override
  Future<void> reconnect() async {}
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iOS is unsupported without touching Android channels', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final client = PlatformNotificationCaptureClient();
    expect(client.supported, isFalse);
    expect((await client.snapshot()).enabled, isFalse);
    expect(await client.changes.toList(), isEmpty);
  });

  test(
    'Android bridge decodes metadata and uses capture commands only',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('spendwise/notification_capture');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'snapshot' => {
                'enabled': true,
                'permissionGranted': true,
                'listenerConnected': false,
                'retentionDays': 1,
                'packages': ['my.com.tngdigital.ewallet'],
                'sources': [
                  {
                    'packageName': 'my.com.tngdigital.ewallet',
                    'name': 'Synthetic source',
                  },
                ],
                'diagnostics': {'lastError': null, 'failures': 0},
              },
              'history' => [
                {
                  'sequence': 1,
                  'eventId': 'synthetic-id',
                  'packageName': 'my.com.tngdigital.ewallet',
                  'notificationId': 42,
                  'postedAt': 1,
                  'capturedAt': 2,
                  'deliveries': 2,
                  'status': 'captured',
                  'contentState': 'retained',
                  'reason': null,
                },
              ],
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final client = PlatformNotificationCaptureClient();
      expect((await client.snapshot()).permissionGranted, isTrue);
      expect((await client.history()).single.deliveries, 2);
      await client.configure(true, ['my.com.tngdigital.ewallet'], 1);
      await client.eraseContent(eventId: 'synthetic-id');
      expect(calls.map((c) => c.method), [
        'snapshot',
        'history',
        'configure',
        'eraseContent',
      ]);
      expect(calls.last.arguments, {'eventId': 'synthetic-id'});
    },
  );

  test(
    'controller exposes failures without clearing previously retained events',
    () async {
      final client = FakeCaptureClient();
      final controller = CaptureController(client);
      await controller.refresh();
      expect(controller.events.single.eventId, 'synthetic-reference');
      client.fail = true;
      await controller.refresh();
      expect(controller.error, isNotNull);
      expect(controller.events, hasLength(1));
      expect(
        await controller.perform(() => client.configure(true, [], 1)),
        isFalse,
      );
      controller.dispose();
      await client.signal.close();
    },
  );

  testWidgets(
    'unsupported tracking remains readable without native initialization',
    (tester) async {
      final client = FakeCaptureClient()..supported = false;
      await tester.pumpWidget(
        MaterialApp(home: AutomaticTrackingScreen(client: client)),
      );
      expect(find.textContaining('only in the Android app'), findsOneWidget);
      expect(client.reads, 0);
      await tester.pumpWidget(const SizedBox());
      await client.signal.close();
    },
  );

  testWidgets(
    'monitoring and source selection are explicit and revocation refreshes status',
    (tester) async {
      final client = FakeCaptureClient();
      await tester.pumpWidget(
        MaterialApp(home: AutomaticTrackingScreen(client: client)),
      );
      await tester.pumpAndSettle();
      expect(client.enabled, isFalse);
      expect(client.packages, isEmpty);
      await tapVisible(tester, find.byType(Switch));
      expect(client.enabled, isTrue);
      await tapVisible(tester, find.text("Touch 'n Go eWallet"));
      expect(client.packages, ['my.com.tngdigital.ewallet']);
      client.granted = true;
      client.connected = true;
      client.signal.add(null);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Granted'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Granted'), findsOneWidget);
      client.granted = false;
      client.signal.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Not granted or revoked'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await client.signal.close();
    },
  );

  testWidgets(
    'capture details reveal raw content only on request and deletion keeps metadata',
    (tester) async {
      final client = FakeCaptureClient();
      await tester.pumpWidget(
        MaterialApp(home: CaptureHistoryScreen(client: client)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic confidential fixture'), findsNothing);
      await tapVisible(tester, find.text("Touch 'n Go eWallet"));
      await tapVisible(tester, find.text('Show retained content'));
      expect(find.text('Synthetic confidential fixture'), findsOneWidget);
      await tapVisible(tester, find.text('Delete this retained content'));
      expect(client.raw, isNull);
      expect(
        find.textContaining('Capture metadata and ledger history remain.'),
        findsOneWidget,
      );
      expect(
        find.text('Capture reference: synthetic-reference'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await client.signal.close();
    },
  );

  testWidgets('backgrounding hides notification content', (tester) async {
    final client = FakeCaptureClient();
    final event = (await client.history()).single;
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureDetailScreen(
          client: client,
          event: event,
          sourceName: 'Synthetic source',
        ),
      ),
    );
    await tapVisible(tester, find.text('Show retained content'));
    expect(find.text('Synthetic confidential fixture'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('Synthetic confidential fixture'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await client.signal.close();
  });
  testWidgets('pending content reads cannot reveal data after background and resume', (tester) async {
    final client = FakeCaptureClient()..delayedContent = Completer<Map<String, Object?>?>();
    final event = (await client.history()).single;
    await tester.pumpWidget(MaterialApp(home: CaptureDetailScreen(client: client, event: event, sourceName: 'Synthetic source')));
    await tapVisible(tester, find.text('Show retained content'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    client.delayedContent!.complete(client.raw);
    await tester.pumpAndSettle();
    expect(find.text('Synthetic confidential fixture'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await client.signal.close();
  });

  testWidgets('tracking settings fit a narrow dark device with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = FakeCaptureClient();
    await tester.pumpWidget(MaterialApp(theme: SpendWiseTheme.dark,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(1.3)), child: child!),
      home: AutomaticTrackingScreen(client: client)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Detection history'), 150,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await client.signal.close();
  });

}
