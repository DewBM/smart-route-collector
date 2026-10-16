/// A stop the collector skipped, queued locally until the server has it.
class SkipRecord {
  final int? id;
  final int tripId;
  final int supplierId;
  final String reason;
  final String? note;
  final String skippedAt;
  final bool synced;

  const SkipRecord({
    this.id,
    required this.tripId,
    required this.supplierId,
    required this.reason,
    this.note,
    required this.skippedAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'tripId': tripId,
    'supplierId': supplierId,
    'reason': reason,
    'note': note,
    'skippedAt': skippedAt,
    'synced': synced ? 1 : 0,
  };

  factory SkipRecord.fromMap(Map<String, dynamic> map) => SkipRecord(
    id: map['id'] as int?,
    tripId: map['tripId'] as int,
    supplierId: map['supplierId'] as int,
    reason: map['reason'] as String,
    note: map['note'] as String?,
    skippedAt: map['skippedAt'] as String,
    synced: map['synced'] == 1,
  );
}
