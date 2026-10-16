import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/trip_stop.dart';

/// Opens Google Maps (app if installed, otherwise the browser) with driving
/// directions from the user's current location to [stop].
Future<void> navigateToStop(BuildContext context, TripStop stop) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${stop.latitude},${stop.longitude}',
    'travelmode': 'driving',
  });

  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}

  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open Google Maps.')),
    );
  }
}
