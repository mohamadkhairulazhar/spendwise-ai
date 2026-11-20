import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../platform/notification_capture.dart';

class CaptureController extends ChangeNotifier {
  CaptureController(this.client);
  final NotificationCaptureClient client;
  CaptureSnapshot snapshot = const CaptureSnapshot();
  List<CaptureEvent> events = [];
  bool busy = false;
  bool hasMore = false;
  String? error;
  bool _disposed = false;
  bool _refreshAgain = false;
  StreamSubscription<void>? _subscription;
  Timer? _poll;

  void start() {
    if (!client.supported) return;
    _subscription = client.changes.listen((_) => refresh(), onError: (_) {
      error = 'Live updates unavailable. Refresh to read retained captures.';
      _notify();
    });
    setForeground(true);
    refresh();
  }

  void setForeground(bool foreground) {
    _poll?.cancel();
    _poll = foreground && client.supported && !_disposed
      ? Timer.periodic(const Duration(seconds: 5), (_) => refresh()) : null;
  }

  Future<void> refresh() async {
    if (_disposed || !client.supported) return;
    if (busy) { _refreshAgain = true; return; }
    busy = true;
    _notify();
    do {
      _refreshAgain = false;
      try {
        final settings = await client.snapshot();
        final history = await client.history();
        if (_disposed) return;
        snapshot = settings;
        events = history;
        hasMore = history.length == 50;
        error = null;
      } catch (_) {
        error = 'Could not read local captures. Retry; no data was reset.';
        _refreshAgain = false;
      }
    } while (_refreshAgain && !_disposed);
    busy = false;
    _notify();
  }

  Future<bool> perform(Future<void> Function() action) async {
    if (busy || _disposed || !client.supported) return false;
    busy = true;
    error = null;
    _notify();
    var ok = false;
    try { await action(); ok = true; }
    catch (_) { error = 'Could not update capture settings. Retry.'; }
    busy = false;
    if (ok) { await refresh(); } else { _notify(); }
    return ok;
  }

  Future<void> loadMore() async {
    if (busy || !hasMore || events.isEmpty) return;
    busy = true;
    _notify();
    try {
      final next = await client.history(before: events.last.sequence);
      if (_disposed) return;
      events = [...events, ...next];
      hasMore = next.length == 50;
    } catch (_) { error = 'Could not load older captures. Retry.'; }
    busy = false;
    _notify();
  }

  String sourceName(String packageName) => snapshot.sources
    .where((s) => s.packageName == packageName).firstOrNull?.name ?? packageName;

  void _notify() { if (!_disposed) notifyListeners(); }
  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
