import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/trip_stop.dart';
import '../models/collection_record.dart';
import '../models/skip_record.dart';

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
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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
        distanceFromPrevKm REAL NOT NULL,
        skipReason TEXT,
        address TEXT,
        contactName TEXT,
        phone TEXT,
        notes TEXT
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
        synced INTEGER NOT NULL DEFAULT 0,
        photoPath TEXT,
        photoSynced INTEGER NOT NULL DEFAULT 0,
        signaturePath TEXT,
        signerName TEXT,
        signatureSynced INTEGER NOT NULL DEFAULT 0
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

    await _createSkipsTable(db);
  }

  Future<void> _createSkipsTable(Database db) => db.execute('''
      CREATE TABLE skips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tripId INTEGER NOT NULL,
        supplierId INTEGER NOT NULL,
        reason TEXT NOT NULL,
        note TEXT,
        skippedAt TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE trip_stops ADD COLUMN skipReason TEXT');
      await _createSkipsTable(db);
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE collections ADD COLUMN signaturePath TEXT');
      await db.execute('ALTER TABLE collections ADD COLUMN signerName TEXT');
      await db.execute(
        'ALTER TABLE collections ADD COLUMN signatureSynced INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      for (final col in ['address', 'contactName', 'phone', 'notes']) {
        await db.execute('ALTER TABLE trip_stops ADD COLUMN $col TEXT');
      }
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE collections ADD COLUMN photoPath TEXT');
      await db.execute(
        'ALTER TABLE collections ADD COLUMN photoSynced INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> cacheTripStops(
    int tripId,
    String tripDate,
    double totalDistanceKm,
    List<TripStop> stops,
  ) async {
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

  Future<List<CollectionRecord>> getPendingPhotos() async {
    final db = await database;
    final maps = await db.query(
      'collections',
      where: 'photoPath IS NOT NULL AND photoSynced = 0',
    );
    return maps.map((m) => CollectionRecord.fromMap(m)).toList();
  }

  Future<void> markPhotoSynced(int supplierId) async {
    final db = await database;
    await db.update(
      'collections',
      {'photoSynced': 1},
      where: 'supplierId = ?',
      whereArgs: [supplierId],
    );
  }

  Future<List<CollectionRecord>> getPendingSignatures() async {
    final db = await database;
    final maps = await db.query(
      'collections',
      where: 'signaturePath IS NOT NULL AND signatureSynced = 0',
    );
    return maps.map((m) => CollectionRecord.fromMap(m)).toList();
  }

  Future<void> markSignatureSynced(int supplierId) async {
    final db = await database;
    await db.update(
      'collections',
      {'signatureSynced': 1},
      where: 'supplierId = ?',
      whereArgs: [supplierId],
    );
  }

  Future<List<CollectionRecord>> getAllCollections() async {
    final db = await database;
    final maps = await db.query('collections');
    return maps.map((m) => CollectionRecord.fromMap(m)).toList();
  }

  Future<void> markStopSkipped(int supplierId, String reason) async {
    final db = await database;
    await db.update(
      'trip_stops',
      {'status': 'Skipped', 'skipReason': reason},
      where: 'supplierId = ?',
      whereArgs: [supplierId],
    );
  }

  Future<void> insertSkip(SkipRecord record) async {
    final db = await database;
    await db.insert('skips', record.toMap());
  }

  Future<List<SkipRecord>> getPendingSkips() async {
    final db = await database;
    final maps = await db.query(
      'skips',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'skippedAt ASC',
    );
    return maps.map(SkipRecord.fromMap).toList();
  }

  Future<void> markSkipSynced(int id) async {
    final db = await database;
    await db.update('skips', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('trip_stops');
    await db.delete('collections');
    await db.delete('skips');
    await db.delete('trip_cache');
  }
}
