class CollectionRecord {
  final int? id;
  final int tripId;
  final int supplierId;
  final double clearKg;
  final double colouredKg;
  final String condition;
  final String collectedAt;
  bool synced;
  final String? photoPath;
  bool photoSynced;
  final String? signaturePath;
  final String? signerName;
  bool signatureSynced;

  CollectionRecord({
    this.id,
    required this.tripId,
    required this.supplierId,
    required this.clearKg,
    required this.colouredKg,
    required this.condition,
    required this.collectedAt,
    this.synced = false,
    this.photoPath,
    this.photoSynced = false,
    this.signaturePath,
    this.signerName,
    this.signatureSynced = false,
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
      'photoPath': photoPath,
      'photoSynced': photoSynced ? 1 : 0,
      'signaturePath': signaturePath,
      'signerName': signerName,
      'signatureSynced': signatureSynced ? 1 : 0,
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
      photoPath: map['photoPath'] as String?,
      photoSynced: map['photoSynced'] == 1,
      signaturePath: map['signaturePath'] as String?,
      signerName: map['signerName'] as String?,
      signatureSynced: map['signatureSynced'] == 1,
    );
  }
}
