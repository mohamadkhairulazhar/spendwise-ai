import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Capture transport only. This API cannot parse or post a ledger transaction.
abstract class NotificationCaptureClient {
  bool get supported;
  Stream<void> get changes;
  Future<CaptureSnapshot> snapshot();
  Future<void> configure(bool enabled, List<String> packages, int retentionDays);
  Future<List<CaptureEvent>> history({int? before});
  Future<Map<String, Object?>?> content(String eventId);
  Future<void> eraseContent({String? eventId});
  Future<void> openAccessSettings();
  Future<void> reconnect();
}

class CaptureSource {
  const CaptureSource(this.packageName, this.name);
  final String packageName;
  final String name;
}

class CaptureSnapshot {
  const CaptureSnapshot({this.enabled = false, this.permissionGranted = false,
    this.listenerConnected = false, this.retentionDays = 1,
    this.packages = const [], this.sources = const [], this.lastError,
    this.failures = 0});
  final bool enabled;
  final bool permissionGranted;
  final bool listenerConnected;
  final int retentionDays;
  final List<String> packages;
  final List<CaptureSource> sources;
  final String? lastError;
  final int failures;

  factory CaptureSnapshot.fromMap(Map<Object?, Object?> value) {
    final diagnostics = value['diagnostics'] as Map? ?? const {};
    return CaptureSnapshot(enabled: value['enabled'] == true,
      permissionGranted: value['permissionGranted'] == true,
      listenerConnected: value['listenerConnected'] == true,
      retentionDays: value['retentionDays'] as int,
      packages: List<String>.from(value['packages'] as List),
      sources: (value['sources'] as List).map((v) => CaptureSource(
        (v as Map)['packageName'] as String, v['name'] as String)).toList(),
      lastError: diagnostics['lastError'] as String?,
      failures: diagnostics['failures'] as int? ?? 0);
  }
}

class CaptureEvent {
  const CaptureEvent({required this.sequence, required this.eventId,
    required this.packageName, required this.postedAt, required this.capturedAt,
    required this.notificationId, required this.deliveries, required this.status,
    required this.contentState, this.reason});
  final int sequence;
  final String eventId;
  final String packageName;
  final DateTime postedAt;
  final DateTime capturedAt;
  final int notificationId;
  final int deliveries;
  final String status;
  final String contentState;
  final String? reason;

  factory CaptureEvent.fromMap(Map<Object?, Object?> value) => CaptureEvent(
    sequence: value['sequence'] as int, eventId: value['eventId'] as String,
    packageName: value['packageName'] as String,
    postedAt: DateTime.fromMillisecondsSinceEpoch(value['postedAt'] as int),
    capturedAt: DateTime.fromMillisecondsSinceEpoch(value['capturedAt'] as int),
    notificationId: value['notificationId'] as int,
    deliveries: value['deliveries'] as int, status: value['status'] as String,
    contentState: value['contentState'] as String, reason: value['reason'] as String?);
}

class PlatformNotificationCaptureClient implements NotificationCaptureClient {
  static const _methods = MethodChannel('spendwise/notification_capture');
  static const _events = EventChannel('spendwise/notification_capture_changes');
  static final _changes = _events.receiveBroadcastStream().map<void>((_) {});
  @override
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Stream<void> get changes => supported
    ? _changes : const Stream.empty();
  @override
  Future<CaptureSnapshot> snapshot() async => supported
    ? CaptureSnapshot.fromMap((await _methods.invokeMapMethod<Object?, Object?>('snapshot'))!)
    : const CaptureSnapshot();
  @override
  Future<void> configure(bool enabled, List<String> packages, int retentionDays) =>
    _methods.invokeMethod('configure', {'enabled': enabled, 'packages': packages,
      'retentionDays': retentionDays});
  @override
  Future<List<CaptureEvent>> history({int? before}) async =>
    ((await _methods.invokeListMethod<Object?>('history', {if (before != null) 'before': before}))!)
      .map((v) => CaptureEvent.fromMap(v as Map<Object?, Object?>)).toList();
  @override
  Future<Map<String, Object?>?> content(String eventId) async =>
    _methods.invokeMapMethod<String, Object?>('content', {'eventId': eventId});
  @override
  Future<void> eraseContent({String? eventId}) =>
    _methods.invokeMethod('eraseContent', {if (eventId != null) 'eventId': eventId});
  @override
  Future<void> openAccessSettings() => _methods.invokeMethod('openAccessSettings');
  @override
  Future<void> reconnect() => _methods.invokeMethod('reconnect');
}
