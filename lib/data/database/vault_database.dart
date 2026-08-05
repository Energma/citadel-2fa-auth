import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/token.dart';
import '../../core/models/profile.dart';

class VaultDatabase {
  static const String _dbName = 'citadel_vault.db';
  static const int _dbVersion = 4;

  Database? _database;

  bool get isOpen => _database != null;

  Future<String> get _dbPath async {
    final dir = await getApplicationSupportDirectory();
    return join(dir.path, _dbName);
  }

  /// Open the encrypted database with the given passphrase.
  Future<void> open(String passphrase) async {
    if (_database != null) return;

    final path = await _dbPath;
    _database = await openDatabase(
      path,
      password: passphrase,
      version: _dbVersion,
      // SQLite never enforces FOREIGN KEY constraints unless this is set on
      // the connection — without it, the declared `ON DELETE CASCADE` /
      // `ON DELETE SET NULL` rules below are inert, and deleting a profile
      // only removes that one row, leaving its groups and tokens dangling.
      // Must run in onConfigure: it runs before onCreate/onUpgrade and
      // outside their transaction, which PRAGMA foreign_keys requires.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Close the database (lock the vault).
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Check if the vault database exists.
  Future<bool> exists() async {
    final path = await _dbPath;
    return databaseExists(path);
  }

  /// Checks whether [passphrase] decrypts the vault, without disturbing the
  /// already-open connection (used to re-confirm a PIN when its digits
  /// aren't stored anywhere, e.g. before turning on biometric unlock later).
  /// `singleInstance: false` is required here — otherwise the plugin would
  /// just hand back the already-open connection for this path and skip
  /// checking the candidate passphrase entirely.
  Future<bool> verifyPassphrase(String passphrase) async {
    final path = await _dbPath;
    try {
      final probe = await openDatabase(
        path,
        password: passphrase,
        readOnly: true,
        singleInstance: false,
      );
      await probe.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete the vault (destructive).
  Future<void> deleteVault() async {
    await close();
    final path = await _dbPath;
    await deleteDatabase(path);
  }

  Database get _db {
    if (_database == null) throw StateError('Vault is locked');
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        iconName TEXT,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        generalSortOrder INTEGER NOT NULL DEFAULT -1,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        profileId TEXT NOT NULL,
        name TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (profileId) REFERENCES profiles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tokens (
        id TEXT PRIMARY KEY,
        issuer TEXT NOT NULL,
        account TEXT NOT NULL,
        secret TEXT NOT NULL,
        type TEXT NOT NULL,
        algorithm TEXT NOT NULL,
        digits INTEGER NOT NULL DEFAULT 6,
        period INTEGER NOT NULL DEFAULT 30,
        counter INTEGER NOT NULL DEFAULT 0,
        iconPath TEXT,
        profileId TEXT,
        groupId TEXT,
        tags TEXT,
        isPinned INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (profileId) REFERENCES profiles(id) ON DELETE SET NULL,
        FOREIGN KEY (groupId) REFERENCES groups(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_tokens_profile ON tokens(profileId)');
    await db.execute('CREATE INDEX idx_tokens_group ON tokens(groupId)');

    // Insert default profiles
    await db.insert('profiles', Profile(
      name: 'Personal',
      colorValue: 0xFF6366F1, // indigo
      sortOrder: 0,
    ).toMap());
    await db.insert('profiles', Profile(
      name: 'Work',
      colorValue: 0xFF06B6D4, // cyan
      sortOrder: 1,
    ).toMap());
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Make groups global (remove profileId dependency)
      await db.execute('''
        CREATE TABLE groups_new (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          sortOrder INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
          'INSERT INTO groups_new (id, name, sortOrder) SELECT id, name, sortOrder FROM groups');
      await db.execute('DROP TABLE groups');
      await db.execute('ALTER TABLE groups_new RENAME TO groups');
    }

    if (oldVersion < 3) {
      // Make groups profile-specific (add profileId back)
      await db.execute('''
        CREATE TABLE groups_new (
          id TEXT PRIMARY KEY,
          profileId TEXT NOT NULL,
          name TEXT NOT NULL,
          sortOrder INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (profileId) REFERENCES profiles(id) ON DELETE CASCADE
        )
      ''');
      // Assign all groups to the first profile (Personal)
      final profiles = await db.query('profiles', orderBy: 'sortOrder ASC');
      if (profiles.isNotEmpty) {
        final firstProfileId = profiles.first['id'] as String;
        await db.execute(
          'INSERT INTO groups_new (id, profileId, name, sortOrder) SELECT id, ?, name, sortOrder FROM groups',
          [firstProfileId],
        );
      }
      await db.execute('DROP TABLE groups');
      await db.execute('ALTER TABLE groups_new RENAME TO groups');
    }

    if (oldVersion < 4) {
      // Add General section's per-profile position for Home-screen reorder.
      await db.execute(
          'ALTER TABLE profiles ADD COLUMN generalSortOrder INTEGER NOT NULL DEFAULT -1');
    }
  }

  // --- Token CRUD ---

  Future<List<Token>> getAllTokens() async {
    final maps = await _db.query('tokens', orderBy: 'sortOrder ASC, createdAt DESC');
    return maps.map((m) => Token.fromMap(m)).toList();
  }

  Future<List<Token>> getTokensByProfile(String profileId) async {
    final maps = await _db.query(
      'tokens',
      where: 'profileId = ?',
      whereArgs: [profileId],
      orderBy: 'isPinned DESC, sortOrder ASC',
    );
    return maps.map((m) => Token.fromMap(m)).toList();
  }

  Future<void> insertToken(Token token) async {
    await _db.insert('tokens', token.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateToken(Token token) async {
    await _db.update('tokens', token.toMap(), where: 'id = ?', whereArgs: [token.id]);
  }

  Future<void> deleteToken(String id) async {
    await _db.delete('tokens', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateHotpCounter(String tokenId, int newCounter) async {
    await _db.update('tokens', {'counter': newCounter}, where: 'id = ?', whereArgs: [tokenId]);
  }

  // --- Profile CRUD ---

  Future<List<Profile>> getAllProfiles() async {
    final maps = await _db.query('profiles', orderBy: 'sortOrder ASC');
    return maps.map((m) => Profile.fromMap(m)).toList();
  }

  Future<void> insertProfile(Profile profile) async {
    await _db.insert('profiles', profile.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateProfile(Profile profile) async {
    await _db.update('profiles', profile.toMap(), where: 'id = ?', whereArgs: [profile.id]);
  }

  Future<void> deleteProfile(String id) async {
    await _db.delete('profiles', where: 'id = ?', whereArgs: [id]);
  }

  // --- Group CRUD ---

  Future<List<TokenGroup>> getAllGroups() async {
    final maps = await _db.query('groups', orderBy: 'sortOrder ASC');
    return maps.map((m) => TokenGroup.fromMap(m)).toList();
  }

  Future<List<TokenGroup>> getGroupsByProfile(String profileId) async {
    final maps = await _db.query(
      'groups',
      where: 'profileId = ?',
      whereArgs: [profileId],
      orderBy: 'sortOrder ASC',
    );
    return maps.map((m) => TokenGroup.fromMap(m)).toList();
  }

  Future<void> insertGroup(TokenGroup group) async {
    await _db.insert('groups', group.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateGroup(TokenGroup group) async {
    await _db.update('groups', group.toMap(), where: 'id = ?', whereArgs: [group.id]);
  }

  Future<void> deleteGroup(String id) async {
    await _db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateGroupSortOrders(Map<String, int> idToOrder) async {
    final batch = _db.batch();
    for (final entry in idToOrder.entries) {
      batch.update('groups', {'sortOrder': entry.value},
          where: 'id = ?', whereArgs: [entry.key]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateTokenGroup(String tokenId, String? groupId) async {
    await _db.update('tokens', {'groupId': groupId},
        where: 'id = ?', whereArgs: [tokenId]);
  }

  // --- Search ---

  Future<List<Token>> searchTokens(String query) async {
    final maps = await _db.query(
      'tokens',
      where: 'issuer LIKE ? OR account LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'isPinned DESC, issuer ASC',
    );
    return maps.map((m) => Token.fromMap(m)).toList();
  }

  // --- Bulk Operations ---

  Future<void> insertTokens(List<Token> tokens) async {
    final batch = _db.batch();
    for (final token in tokens) {
      batch.insert('tokens', token.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int> tokenCount() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as count FROM tokens');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Batch update token sort orders.
  Future<void> updateTokenSortOrders(Map<String, int> idToOrder) async {
    final batch = _db.batch();
    for (final entry in idToOrder.entries) {
      batch.update('tokens', {'sortOrder': entry.value},
          where: 'id = ?', whereArgs: [entry.key]);
    }
    await batch.commit(noResult: true);
  }

  /// Batch update profile sort orders.
  Future<void> updateProfileSortOrders(Map<String, int> idToOrder) async {
    final batch = _db.batch();
    for (final entry in idToOrder.entries) {
      batch.update('profiles', {'sortOrder': entry.value},
          where: 'id = ?', whereArgs: [entry.key]);
    }
    await batch.commit(noResult: true);
  }

  /// Update where the synthetic "General" section sits among [profileId]'s
  /// groups on the Home screen.
  Future<void> updateGeneralSortOrder(String profileId, int order) async {
    await _db.update('profiles', {'generalSortOrder': order},
        where: 'id = ?', whereArgs: [profileId]);
  }

  /// Update a token's profile assignment.
  Future<void> updateTokenProfile(String tokenId, String? profileId) async {
    await _db.update('tokens', {'profileId': profileId},
        where: 'id = ?', whereArgs: [tokenId]);
  }

  /// Re-key the database with a new passphrase (for PIN changes).
  Future<void> rekey(String newPassphrase) async {
    await _db.rawQuery("PRAGMA rekey = '$newPassphrase'");
  }
}
