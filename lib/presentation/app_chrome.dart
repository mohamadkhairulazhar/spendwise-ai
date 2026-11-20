import 'package:flutter/material.dart';

/// A narrow, readable canvas on desktop; a full-width native layout on phones.
class FinanceScaffold extends StatelessWidget {
  const FinanceScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
  });
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              if (const bool.fromEnvironment('SPENDWISE_DEMO'))
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'SYNTHETIC DEMO · Invented MYR data · Do not enter real financial information',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    ),
    floatingActionButton: floatingActionButton,
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          height: 1.5,
        ),
      ),
    ),
  );
}
