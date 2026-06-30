import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

const _bibleAsset = 'assets/db/bible.db';
const _bibleFile = 'bible.db';
const _appFile = 'app.db';

/// Must match the `user_version` baked into assets/db/bible.db by the build tool.
const bibleSchemaVersion = 2; // bump → installer re-copies the rebuilt asset
const appSchemaVersion = 2; // v2 = sync columns + group mirror (P3b)

/// Opened handles to both databases. Bible is read-only; app is writable.
class AppDatabases {
  AppDatabases(this.bible, this.app);
  final Database bible;
  final Database app;

  void dispose() {
    bible.dispose();
    app.dispose();
  }
}

/// Installs the bundled bible.db (once / on version bump), opens it read-only,
/// and opens+migrates the writable app.db. Runs behind the startup gate.
final databasesProvider = FutureProvider<AppDatabases>((ref) async {
  final dir = await getApplicationSupportDirectory();
  final biblePath = p.join(dir.path, _bibleFile);
  final appPath = p.join(dir.path, _appFile);

  await _installBibleIfNeeded(biblePath);

  final bible = sqlite3.open(biblePath, mode: OpenMode.readOnly);
  final app = sqlite3.open(appPath);
  _migrateApp(app);

  final dbs = AppDatabases(bible, app);
  ref.onDispose(dbs.dispose);
  return dbs;
});

Future<void> _installBibleIfNeeded(String path) async {
  final file = File(path);
  if (file.existsSync() && _installedVersion(path) == bibleSchemaVersion) {
    return;
  }
  // Clear any stale sidecars, then copy the asset bytes to a real file.
  for (final ext in ['', '-wal', '-shm', '-journal']) {
    final f = File('$path$ext');
    if (f.existsSync()) f.deleteSync();
  }
  final data = await rootBundle.load(_bibleAsset);
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes, flush: true);
}

int? _installedVersion(String path) {
  Database? db;
  try {
    db = sqlite3.open(path, mode: OpenMode.readOnly);
    final row = db.select('PRAGMA user_version').first;
    return row.values.first as int?;
  } catch (_) {
    return null;
  } finally {
    db?.dispose();
  }
}

void _migrateApp(Database app) {
  final version = (app.select('PRAGMA user_version').first.values.first as int?) ?? 0;
  if (version >= appSchemaVersion) return;

  if (version < 1) {
    app.execute('''
      CREATE TABLE IF NOT EXISTS plans(
        id TEXT PRIMARY KEY,
        start_book TEXT, start_chapter INTEGER,
        end_book TEXT, end_chapter INTEGER,
        chapters_per_day INTEGER,
        start_date TEXT,
        is_active INTEGER,
        updated_at TEXT
      );
      CREATE TABLE IF NOT EXISTS reading_progress(
        id TEXT PRIMARY KEY,
        plan_id TEXT,
        book_code TEXT, chapter INTEGER,
        day_index INTEGER,
        local_date TEXT,
        completed_at TEXT,
        updated_at TEXT,
        UNIQUE(plan_id, day_index)
      );
      CREATE INDEX IF NOT EXISTS ix_progress_date ON reading_progress(local_date);
    ''');
  }
  if (version < 2) {
    // P3b "Read Together": account-scoped sync + a local mirror of the active
    // group. All additive — pre-account rows stay valid (user_id/group_id NULL).
    // reading_progress gains: who owns the row, which group plan it aligns to,
    // and a dirty flag the SupabaseSyncService drains (no-op for local users).
    app.execute('''
      ALTER TABLE reading_progress ADD COLUMN user_id TEXT;
      ALTER TABLE reading_progress ADD COLUMN group_id TEXT;
      ALTER TABLE reading_progress ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0;
      CREATE INDEX IF NOT EXISTS ix_progress_dirty ON reading_progress(dirty);

      CREATE TABLE IF NOT EXISTS groups(
        id TEXT PRIMARY KEY,
        name TEXT,
        join_code TEXT,
        start_book TEXT, start_chapter INTEGER,
        end_book TEXT, end_chapter INTEGER,
        chapters_per_day INTEGER,
        start_date TEXT,
        my_role TEXT,
        is_active INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS group_members(
        group_id TEXT,
        user_id TEXT,
        display_name TEXT,
        avatar_emoji TEXT,
        role TEXT,
        PRIMARY KEY(group_id, user_id)
      );
      CREATE TABLE IF NOT EXISTS group_member_progress(
        group_id TEXT,
        user_id TEXT,
        day_index INTEGER,
        PRIMARY KEY(group_id, user_id, day_index)
      );
      CREATE TABLE IF NOT EXISTS sync_state(
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');
  }
  // Future additive migrations go here, each guarded by `if (version < N)`.

  app.execute('PRAGMA user_version=$appSchemaVersion;');
}
