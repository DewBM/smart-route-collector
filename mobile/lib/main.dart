import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/trip_provider.dart';
import 'providers/collection_provider.dart';
import 'providers/sync_manager.dart';
import 'providers/sync_provider.dart';
import 'providers/analytics_provider.dart';
import 'screens/home_shell.dart';
import 'services/photo_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PhotoService().pruneOlderThan().catchError((_) {});
  runApp(const SmartRouteApp());
}

class SmartRouteApp extends StatelessWidget {
  const SmartRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SyncManager()),
        ChangeNotifierProvider(
          create: (ctx) => TripProvider(ctx.read<SyncManager>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => CollectionProvider(ctx.read<SyncManager>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => SyncProvider(ctx.read<SyncManager>()),
        ),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
      ],
      child: MaterialApp(
        title: 'Glassline',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        // Respect the user's font size, but cap it so the dense hero layouts
        // stay intact.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: child!,
        ),
        home: const HomeShell(),
      ),
    );
  }
}
