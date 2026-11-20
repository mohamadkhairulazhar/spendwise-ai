import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import 'data/sqlite_finance_repository.dart';
import 'presentation/finance_controller.dart';
import 'presentation/app_theme.dart';
import 'presentation/screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpendWiseApp());
}

class SpendWiseApp extends StatelessWidget {
  const SpendWiseApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SpendWise AI',
    theme: SpendWiseTheme.light,
    darkTheme: SpendWiseTheme.dark,
    themeMode: ThemeMode.system,
    home: const _Startup(),
  );
}

class _Startup extends StatefulWidget {
  const _Startup();
  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  late Future<SqliteFinanceRepository> _opening;
  SqliteFinanceRepository? _repository;
  @override
  void initState() {
    super.initState();
    _opening = _open();
  }

  Future<SqliteFinanceRepository> _open() async {
    const demo = bool.fromEnvironment('SPENDWISE_DEMO');
    final repository = await SqliteFinanceRepository.open(
      databasePath: kIsWeb
          ? (demo ? 'spendwise-demo-v1.db' : 'spendwise.db')
          : null,
    );
    if (demo) {
      try {
        await repository.seedSyntheticDemo();
      } catch (_) {
        await repository.close();
        rethrow;
      }
    }
    _repository = repository;
    return repository;
  }

  @override
  void dispose() {
    _repository?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SqliteFinanceRepository>(
    future: _opening,
    builder: (context, state) {
      if (state.hasError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to open local storage. Your data has not been reset.',
                ),
                FilledButton(
                  onPressed: () => setState(() {
                    _opening = _open();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      if (!state.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return ChangeNotifierProvider(
        create: (_) => FinanceController(state.data!)..refresh(),
        child: const FinanceHome(),
      );
    },
  );
}
