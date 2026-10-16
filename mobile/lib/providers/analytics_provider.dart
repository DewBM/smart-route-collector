import 'package:flutter/foundation.dart';
import '../models/analytics.dart';
import '../services/api_service.dart';

/// Server-backed, read-only data for the History and Insights tabs.
class AnalyticsProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  List<TripHistoryItem> history = [];
  bool historyLoading = false;
  String? historyError;

  Insights? insights;
  int insightsDays = 7;
  bool insightsLoading = false;
  String? insightsError;

  Future<void> loadHistory() async {
    historyLoading = true;
    historyError = null;
    notifyListeners();
    try {
      history = await _api.fetchHistory();
    } catch (_) {
      historyError = "Couldn't load trip history. Check your connection.";
    } finally {
      historyLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadInsights({int? days}) async {
    if (days != null) insightsDays = days;
    insightsLoading = true;
    insightsError = null;
    notifyListeners();
    try {
      insights = await _api.fetchInsights(insightsDays);
    } catch (_) {
      insightsError = "Couldn't load insights. Check your connection.";
    } finally {
      insightsLoading = false;
      notifyListeners();
    }
  }
}
