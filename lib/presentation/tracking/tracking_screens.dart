import 'package:flutter/material.dart';
import '../../platform/notification_capture.dart';
import '../app_chrome.dart';
import 'capture_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => FinanceScaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Automatic Tracking'),
          subtitle: const Text('Android notification capture'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AutomaticTrackingScreen(),
            ),
          ),
        ),
      ],
    ),
  );
}

class AutomaticTrackingScreen extends StatefulWidget {
  const AutomaticTrackingScreen({super.key, this.client});
  final NotificationCaptureClient? client;
  @override
  State<AutomaticTrackingScreen> createState() =>
      _AutomaticTrackingScreenState();
}

class _AutomaticTrackingScreenState extends State<AutomaticTrackingScreen>
    with WidgetsBindingObserver {
  late final CaptureController model;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    model = CaptureController(
      widget.client ?? PlatformNotificationCaptureClient(),
    );
    model.addListener(_changed);
    model.start();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    model.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) model.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model.removeListener(_changed);
    model.dispose();
    super.dispose();
  }

  Future<void> _configure({
    bool? enabled,
    List<String>? packages,
    int? days,
  }) async {
    await model.perform(
      () => model.client.configure(
        enabled ?? model.snapshot.enabled,
        packages ?? model.snapshot.packages,
        days ?? model.snapshot.retentionDays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = model.snapshot;
    return FinanceScaffold(
      appBar: AppBar(title: const Text('Automatic Tracking')),
      body: !model.client.supported
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Notification capture is available only in the Android app. iOS and Web continue to support manual finance tracking.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              children: [
                const Text(
                  'Capture only',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This release retains selected notifications for inspection. It does not parse transactions or change balances. No banking notification format has been validated yet.',
                ),
                const SizedBox(height: 16),
                if (model.error != null) ErrorNotice(model.error!),
                if (model.busy) const LinearProgressIndicator(minHeight: 2),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notification Access'),
                  subtitle: Text(
                    data.permissionGranted
                        ? 'Granted'
                        : 'Not granted or revoked',
                  ),
                  trailing: TextButton(
                    onPressed: model.busy
                        ? null
                        : () => model.perform(model.client.openAccessSettings),
                    child: const Text('Open settings'),
                  ),
                ),
                const Text(
                  'Android grants access to all notifications. SpendWise reads and stores text only from applications you explicitly select. Sensitive-code screening can omit content; no banking credentials are requested.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notification capture'),
                  value: data.enabled,
                  subtitle: const Text(
                    'Off by default. Captures stay on this device.',
                  ),
                  onChanged: model.busy ? null : (v) => _configure(enabled: v),
                ),
                if (data.enabled && data.packages.isEmpty)
                  const Text(
                    'No applications selected. Choose at least one source below.',
                  ),
                Text(
                  !data.permissionGranted
                      ? 'Capture cannot receive events without Notification Access.'
                      : !data.enabled
                      ? 'Capture disabled.'
                      : data.listenerConnected
                      ? 'Listener connected.'
                      : 'Waiting for Android to connect the listener.',
                ),
                TextButton(
                  onPressed:
                      model.busy || !data.permissionGranted || !data.enabled
                      ? null
                      : () => model.perform(model.client.reconnect),
                  child: const Text('Reconnect listener'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Monitored applications',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Text(
                  'Package identities verified; capture and formats still require physical-device verification.',
                  style: TextStyle(fontSize: 12),
                ),
                for (final source in data.sources)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(source.name),
                    subtitle: Text(
                      source.packageName,
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: data.packages.contains(source.packageName),
                    onChanged: model.busy
                        ? null
                        : (v) {
                            final packages = [...data.packages]
                              ..remove(source.packageName);
                            if (v == true) packages.add(source.packageName);
                            _configure(packages: packages);
                          },
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey(data.retentionDays),
                  initialValue: data.retentionDays,
                  decoration: const InputDecoration(
                    labelText: 'Raw content retention',
                  ),
                  items: [
                    for (final days in [1, 7, 30])
                      DropdownMenuItem(
                        value: days,
                        child: Text('$days ${days == 1 ? 'day' : 'days'}'),
                      ),
                  ],
                  onChanged: model.busy
                      ? null
                      : (v) {
                          if (v != null) _configure(days: v);
                        },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Expired or deleted raw content cannot be recovered for later parsing. Expiry is enforced before reads and on capture; physical cleanup runs when the app or listener executes. Minimal capture metadata remains.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: model.busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                CaptureHistoryScreen(client: model.client),
                          ),
                        ),
                  child: const Text('Detection history'),
                ),
                const SizedBox(height: 16),
                if (data.lastError != null)
                  Text(
                    'Last capture diagnostic: ${data.lastError} · ${data.failures} failures. No notification contents are logged.',
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Android can delay or miss notifications. Force-stop, reboot, locked-device restrictions and Xiaomi HyperOS battery controls can interrupt delivery. Captures already committed remain available after restart.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
    );
  }
}

class CaptureHistoryScreen extends StatefulWidget {
  const CaptureHistoryScreen({super.key, required this.client});
  final NotificationCaptureClient client;
  @override
  State<CaptureHistoryScreen> createState() => _CaptureHistoryScreenState();
}

class _CaptureHistoryScreenState extends State<CaptureHistoryScreen>
    with WidgetsBindingObserver {
  late final CaptureController model;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    model = CaptureController(widget.client)..addListener(_changed);
    model.start();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    model.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) model.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model.removeListener(_changed);
    model.dispose();
    super.dispose();
  }

  Future<void> _eraseAll() async {
    final erase = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete retained content?'),
        content: const Text(
          'Raw notification text and identifiers will be removed. Capture metadata and financial audit records remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (erase == true && mounted) {
      await model.perform(() => model.client.eraseContent());
    }
  }

  @override
  Widget build(BuildContext context) => FinanceScaffold(
    appBar: AppBar(
      title: const Text('Detection history'),
      actions: [
        IconButton(
          tooltip: 'Refresh captures',
          onPressed: model.busy ? null : model.refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Delete retained content',
          onPressed: model.busy ? null : _eraseAll,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      children: [
        const Text(
          'Native capture inbox',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text(
          'These are notifications, not verified financial transactions. Capture IDs survive restart. Parsing and automatic ledger posting are not enabled.',
        ),
        if (model.error != null) ErrorNotice(model.error!),
        if (model.busy) const LinearProgressIndicator(minHeight: 2),
        if (!model.busy && model.events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No captured notifications yet.'),
          ),
        for (final event in model.events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(model.sourceName(event.packageName)),
            subtitle: Text(
              '${event.postedAt.toLocal().toIso8601String()}\n${event.status} · ${event.reason ?? event.contentState} · ${event.deliveries} deliveries',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CaptureDetailScreen(
                    client: widget.client,
                    event: event,
                    sourceName: model.sourceName(event.packageName),
                  ),
                ),
              );
              model.refresh();
            },
          ),
        if (model.hasMore)
          TextButton(
            onPressed: model.busy ? null : model.loadMore,
            child: const Text('Load older captures'),
          ),
      ],
    ),
  );
}

class CaptureDetailScreen extends StatefulWidget {
  const CaptureDetailScreen({
    super.key,
    required this.client,
    required this.event,
    required this.sourceName,
  });
  final NotificationCaptureClient client;
  final CaptureEvent event;
  final String sourceName;
  @override
  State<CaptureDetailScreen> createState() => _CaptureDetailScreenState();
}

class _CaptureDetailScreenState extends State<CaptureDetailScreen>
    with WidgetsBindingObserver {
  Map<String, Object?>? _content;
  String? _notice;
  bool _busy = false;
  bool _foreground = true;
  int _visibilityGeneration = 0;
  String? _contentState;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _content = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && mounted) {
      _visibilityGeneration++;
      setState(() {
        _content = null;
      });
    }
  }

  Future<void> _show() async {
    setState(() => _busy = true);
    final generation = _visibilityGeneration;
    try {
      final value = await widget.client.content(widget.event.eventId);
      if (mounted && _foreground && generation == _visibilityGeneration) {
        setState(() {
          _content = value;
          _notice = value == null
              ? 'Content omitted, expired, deleted or unavailable.'
              : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice =
              'Could not decrypt retained content. Retry; data was not reset.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _erase() async {
    setState(() => _busy = true);
    try {
      await widget.client.eraseContent(eventId: widget.event.eventId);
      if (mounted) {
        setState(() {
          _content = null;
          _contentState = 'deleted';
          _notice =
              'Retained content deleted. Capture metadata and ledger history remain.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notice = 'Could not delete retained content. Retry.');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => FinanceScaffold(
    appBar: AppBar(title: const Text('Captured notification')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(widget.sourceName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(widget.event.packageName),
        Text(
          'Notification time: ${widget.event.postedAt.toLocal().toIso8601String()}',
        ),
        Text(
          'Captured: ${widget.event.capturedAt.toLocal().toIso8601String()}',
        ),
        Text('Status: ${widget.event.status}'),
        Text('Content: ${_contentState ?? widget.event.contentState}'),
        Text(
          'Reason: ${widget.event.reason ?? 'Awaiting a future verified parser'}',
        ),
        Text('Notification ID: ${widget.event.notificationId}'),
        Text('Deliveries: ${widget.event.deliveries}'),
        Text(
          'Capture reference: ${widget.event.eventId}',
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 16),
        const Text(
          'Raw content is sensitive. Do not share real banking notifications in screenshots, logs or bug reports.',
        ),
        const SizedBox(height: 16),
        if (_notice != null) Text(_notice!),
        if (_content == null)
          FilledButton(
            onPressed: _busy ? null : _show,
            child: const Text('Show retained content'),
          ),
        if (_content != null) ...[
          Text(
            _content!['title'] as String? ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(_content!['body'] as String? ?? ''),
          const SizedBox(height: 8),
          Text('Notification key: ${_content!['notificationKey']}'),
          Text('Tag: ${_content!['tag'] ?? 'None'}'),
          Text('Group: ${_content!['groupKey'] ?? 'None'}'),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: _busy ? null : _erase,
          child: const Text('Delete this retained content'),
        ),
      ],
    ),
  );
}
