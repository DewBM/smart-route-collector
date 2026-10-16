import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../models/trip_stop.dart';
import '../../theme/app_tokens.dart';

/// OpenStreetMap view of the route: road-following polyline in visit order
/// (from the public OSRM router, falling back to straight segments offline),
/// numbered markers coloured by status.
class RouteMap extends StatefulWidget {
  const RouteMap({super.key, required this.stops, this.onStopTap});

  final List<TripStop> stops;
  final ValueChanged<TripStop>? onStopTap;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  // Roads don't change between rebuilds; keep the last fetched geometry.
  static String? _cachedKey;
  static List<LatLng>? _cachedRoad;

  List<LatLng>? _road;

  List<LatLng> get _points =>
      widget.stops.map((s) => LatLng(s.latitude, s.longitude)).toList();

  String get _key =>
      _points.map((p) => '${p.latitude},${p.longitude}').join(';');

  @override
  void initState() {
    super.initState();
    _loadRoad();
  }

  Future<void> _loadRoad() async {
    final key = _key;
    if (key == _cachedKey && _cachedRoad != null) {
      _road = _cachedRoad;
      return;
    }
    if (_points.length < 2) return;

    try {
      final coords = _points
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final res = await http
          .get(
            Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/$coords'
              '?overview=full&geometries=geojson',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;

      final line =
          (jsonDecode(res.body)['routes'][0]['geometry']['coordinates'] as List)
              .map(
                (c) =>
                    LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
              )
              .toList();
      _cachedKey = key;
      _cachedRoad = line;
      if (mounted) setState(() => _road = line);
    } catch (_) {
      // Offline or router down: keep the straight-line fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    final points = _points;
    final s = context.status;
    final dark = context.theme.brightness == Brightness.dark;

    final map = FlutterMap(
      options: MapOptions(
        initialCameraFit: points.length > 1
            ? CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.all(56),
              )
            : null,
        initialCenter: points.first,
        initialZoom: 13,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.smartroute.smart_route',
          // OSM has no dark style; invert + dim the tiles only.
          tileBuilder: dark
              ? (context, tile, _) => ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    -0.55,
                    0,
                    0,
                    0,
                    235,
                    0,
                    -0.55,
                    0,
                    0,
                    235,
                    0,
                    0,
                    -0.55,
                    0,
                    235,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ]),
                  child: tile,
                )
              : null,
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: _road ?? points,
              strokeWidth: 6,
              color: s.next.withValues(alpha: 0.9),
              borderStrokeWidth: 2,
              borderColor: Colors.white.withValues(alpha: 0.9),
              strokeJoin: StrokeJoin.round,
              strokeCap: StrokeCap.round,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final stop in stops)
              Marker(
                point: LatLng(stop.latitude, stop.longitude),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => widget.onStopTap?.call(stop),
                  child: Semantics(
                    button: true,
                    label:
                        'Stop ${stop.stopOrder}, ${stop.supplierName}, ${stop.status}',
                    excludeSemantics: true,
                    child: _Pin(stop: stop),
                  ),
                ),
              ),
          ],
        ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
        ),
      ],
    );

    return ClipRRect(borderRadius: Corners.lgAll, child: map);
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.stop});

  final TripStop stop;

  @override
  Widget build(BuildContext context) {
    final s = context.status;
    final (bg, fg) = switch (stop.status) {
      'Collected' => (s.success, Colors.white),
      'Skipped' => (s.warning, Colors.white),
      'Next' => (s.next, context.colors.surface),
      _ => (context.colors.surfaceContainerLowest, context.colors.onSurface),
    };

    return Container(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: stop.status == 'Collected'
          ? Icon(Icons.check_rounded, size: 20, color: fg)
          : stop.status == 'Skipped'
          ? Icon(Icons.skip_next_rounded, size: 20, color: fg)
          : Text(
              '${stop.stopOrder}',
              style: context.text.labelLarge?.copyWith(color: fg),
            ),
    );
  }
}
