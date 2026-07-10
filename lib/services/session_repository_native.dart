// Native implementation: SQLite via sqflite + sqflite_common_ffi
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/session.dart';

Database? _db;

Future<Database> _getDb() async {
  if (_db != null) return _db!;

  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'writesense.db');

  _db = await openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE sessions (
          id TEXT PRIMARY KEY,
          timestamp INTEGER NOT NULL,
          strokes_json TEXT NOT NULL,
          features_json TEXT NOT NULL,
          irregularity_index REAL NOT NULL,
          classification TEXT NOT NULL
        )
      ''');
    },
  );
  return _db!;
}

Future<void> insertSession(Session session) async {
  final db = await _getDb();
  await db.insert(
    'sessions',
    {
      'id': session.id,
      'timestamp': session.timestamp.millisecondsSinceEpoch,
      'strokes_json': session.strokesJson,
      'features_json': session.featuresJson,
      'irregularity_index': session.irregularityIndex,
      'classification': session.classification,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<List<Session>> getAllSessions() async {
  final db = await _getDb();
  final rows = await db.query('sessions', orderBy: 'timestamp DESC');
  return rows.map(Session.fromDbRow).toList();
}

Future<Session?> getSessionById(String id) async {
  final db = await _getDb();
  final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
  if (rows.isEmpty) return null;
  return Session.fromDbRow(rows.first);
}

Future<void> deleteSession(String id) async {
  final db = await _getDb();
  await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
}
