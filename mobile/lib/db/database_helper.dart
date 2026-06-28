import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/trip_stop.dart';
import '../models/collection_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_route.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE trip_stops (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplierId INTEGER NOT NULL,
        supplierName TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        barcodeRef TEXT NOT NULL,
        expectedClearKg REAL NOT NULL,
        expectedColouredKg REAL NOT NULL,
        status TEXT NOT NULL,
        stopOrder INTEGER NOT NULL,
        distanceFromPrevKm REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tripId INTEGER NOT NULL,
        supplierId INTEGER NOT NULL,
        clearKg REAL NOT NULL,
        colouredKg REAL NOT NULL,
        condition TEXT NOT NULL,
        collectedAt TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE trip_cache (
        id INTEGER PRIMARY KEY,
        tripId INTEGER NOT NULL,
        tripDate TEXT NOT NULL,
        totalDistanceKm REAL NOT NULL
      )
    ''');
  }

  Future<void> cacheTripStops(int tripId, String tripDate, double totalDistanceKm, List<TripStop> stops) async {
    final db = await database;

    await db.delete('trip_stops');
    await db.delete('trip_cache');

    await db.insert('trip_cache', {
      'id': 1,
      'tripId': tripId,
      'tripDate': tripDate,
      'totalDistanceKm': totalDistanceKm,
    });

    for (final stop in stops) {
      await db.insert('trip_stops', stop.toMap());
    }
  }

  Future<List<TripStop>> getCachedStops() async {
    final db = await database;
    final maps = await db.query('trip_stops', orderBy: 'stopOrder ASC');
    return maps.map((m) => TripStop.fromMap(m)).toList();
  }

  Future<Map<String, dynamic>?> getCachedTripMeta() async {
    final db = await database;
    final results = await db.query('trip_cache', limit: 1);
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<void> updateStopStatus(int supplierId, String status) async {
    final db = await database;
    await db.update(
      'trip_stops',
      {'status': status},
      where: 'supplierId = ?',
      whereArgs: [supplierId],
    );
  }

  Future<void> insertCollection(CollectionRecord record) async {
    final db = await database;
    await db.insert('collections', record.toMap());
  }

  Future<void> markCollectionSynced(int supplierId) async {
    final db = await database;
    await db.update(
      'collections',
      {'synced': 1},
      where: 'supplierId = ?',
      whereArgs: [supplierId],
    );
  }

  Future<List<CollectionRecord>> getUnsyncedCollections() async {
    final db = await database;
    final maps = await db.query(
      'collections',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return maps.map((m) => CollectionRecord.fromMap(m)).toList();
  }

  Future<List<CollectionRecord>> getAllCollections() async {
    final db = await database;
    final maps = await db.query('collections');
    return maps.map((m) => CollectionRecord.fromMap(m)).toList();
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('trip_stops');
    await db.delete('collections');
    await db.delete('trip_cache');
  }
}
