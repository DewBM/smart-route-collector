const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Mon, 29 Sep" from an ISO date string; falls back to the raw string.
String formatTripDate(String iso) {
  var d = DateTime.tryParse(iso);
  if (d == null) {
    // Backend may send M/d/yyyy.
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(iso);
    if (m != null) {
      d = DateTime.tryParse(
        '${m[3]}-${m[1]!.padLeft(2, '0')}-${m[2]!.padLeft(2, '0')}',
      );
    }
  }
  if (d == null) return iso;
  return '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
}

/// Kilograms without trailing zeros: 12 -> "12", 12.5 -> "12.5".
String formatKg(double kg) =>
    kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

/// "1h 05m" / "42m" / "--"
String formatDuration(Duration? d) {
  if (d == null) return '--';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
}
