class CollectionRecord {
  final int? id;
  final int tripId;
  final int supplierId;
  final double clearKg;
  final double colouredKg;
  final String condition;
  final String collectedAt;
  bool synced;

  CollectionRecord({
    this.id,
    required this.tripId,
    required this.supplierId,
    required this.clearKg,
    required this.colouredKg,
    required this.condition,
    required this.collectedAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tripId': tripId,
      'supplierId': supplierId,
      'clearKg': clearKg,
      'colouredKg': colouredKg,
      'condition': condition,
      'collectedAt': collectedAt,
      'synced': synced ? 1 : 0,
    };
  }

  factory CollectionRecord.fromMap(Map<String, dynamic> map) {
    return CollectionRecord(
      id: map['id'] as int?,
      tripId: map['tripId'] as int,
      supplierId: map['supplierId'] as int,
      clearKg: map['clearKg'] as double,
      colouredKg: map['colouredKg'] as double,
      condition: map['condition'] as String,
      collectedAt: map['collectedAt'] as String,
      synced: map['synced'] == 1,
    );
  }
}
