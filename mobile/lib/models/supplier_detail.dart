class SupplierCollection {
  final DateTime date;
  final double clearKg;
  final double colouredKg;
  final String condition;
  final bool belowExpected;

  const SupplierCollection({
    required this.date,
    required this.clearKg,
    required this.colouredKg,
    required this.condition,
    required this.belowExpected,
  });

  double get totalKg => clearKg + colouredKg;

  factory SupplierCollection.fromJson(Map<String, dynamic> json) =>
      SupplierCollection(
        date: DateTime.parse(json['tripDate'] as String),
        clearKg: (json['clearKg'] as num).toDouble(),
        colouredKg: (json['colouredKg'] as num).toDouble(),
        condition: json['condition'] as String,
        belowExpected: json['belowExpected'] as bool,
      );
}

/// Server-side extras for a supplier: collection history and averages.
class SupplierHistory {
  final int totalCollections;
  final double averageKg;
  final List<SupplierCollection> recent;

  const SupplierHistory({
    required this.totalCollections,
    required this.averageKg,
    required this.recent,
  });

  factory SupplierHistory.fromJson(Map<String, dynamic> json) =>
      SupplierHistory(
        totalCollections: json['totalCollections'] as int,
        averageKg: (json['averageKgPerCollection'] as num).toDouble(),
        recent: (json['recentCollections'] as List)
            .map((c) => SupplierCollection.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}
