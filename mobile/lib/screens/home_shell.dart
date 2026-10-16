import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/analytics_provider.dart';
import '../widgets/sync_status_bar.dart';
import 'history/history_screen.dart';
import 'insights/insights_screen.dart';
import 'trip_sequence/trip_sequence_screen.dart';

/// Bottom-navigation shell: Route (today's trip), History, Insights.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _visited = <int>{0};

  void _select(int i) {
    final analytics = context.read<AnalyticsProvider>();
    // Refresh server-backed tabs every time they are opened; the previous data
    // stays visible while the request runs.
    if (i == 1) analytics.loadHistory();
    if (i == 2) analytics.loadInsights();
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const TripSequenceScreen(),
          _visited.contains(1) ? const HistoryScreen() : const SizedBox(),
          _visited.contains(2) ? const InsightsScreen() : const SizedBox(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SyncStatusBar(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route_rounded),
                label: 'Route',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_rounded),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Insights',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
