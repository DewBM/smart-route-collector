class TripStop {
  final int supplierId;
  final String supplierName;
  final double latitude;
  final double longitude;
  final String barcodeRef;
  final double expectedClearKg;
  final double expectedColouredKg;
  String status;
  final int stopOrder;
  final double distanceFromPrevKm;

  TripStop({
    required this.supplierId,
    required this.supplierName,
    required this.latitude,
    required this.longitude,
    required this.barcodeRef,
    required this.expectedClearKg,
    required this.expectedColouredKg,
    required this.status,
    required this.stopOrder,
    required this.distanceFromPrevKm,
  });

  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      supplierId: json['supplierId'] as int,
      supplierName: json['supplierName'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      barcodeRef: json['barcodeRef'] as String,
      expectedClearKg: (json['expectedClearKg'] as num).toDouble(),
      expectedColouredKg: (json['expectedColouredKg'] as num).toDouble(),
      status: json['status'] as String,
      stopOrder: json['stopOrder'] as int,
      distanceFromPrevKm: (json['distanceFromPrevKm'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierId': supplierId,
      'supplierName': supplierName,
      'latitude': latitude,
      'longitude': longitude,
      'barcodeRef': barcodeRef,
      'expectedClearKg': expectedClearKg,
      'expectedColouredKg': expectedColouredKg,
      'status': status,
      'stopOrder': stopOrder,
      'distanceFromPrevKm': distanceFromPrevKm,
    };
  }

  factory TripStop.fromMap(Map<String, dynamic> map) {
    return TripStop(
      supplierId: map['supplierId'] as int,
      supplierName: map['supplierName'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      barcodeRef: map['barcodeRef'] as String,
      expectedClearKg: map['expectedClearKg'] as double,
      expectedColouredKg: map['expectedColouredKg'] as double,
      status: map['status'] as String,
      stopOrder: map['stopOrder'] as int,
      distanceFromPrevKm: map['distanceFromPrevKm'] as double,
    );
  }
}
