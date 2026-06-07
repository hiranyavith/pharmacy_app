// lib/db/db_helper.dart
import 'package:mysql_client/mysql_client.dart';

class DBHelper {
  static DBHelper? _instance;
  static MySQLConnection? _conn;

  DBHelper._();
  static DBHelper get instance => _instance ??= DBHelper._();

  static const String _host     = 'localhost';
  static const int    _port     = 3306;
  static const String _user     = 'root';
  static const String _password = 'Inter@357#%&';
  static const String _db       = 'pharmacy_db';


  Future<MySQLConnection> get connection async {
    if (_conn != null && _conn!.connected) return _conn!;
    _conn = await MySQLConnection.createConnection(
      host: _host, port: _port,
      userName: _user, password: _password, databaseName: _db,
    );
    await _conn!.connect(); // ← THIS LINE was missing
    return _conn!;
  }

  Future<List<Map<String, dynamic>>> query(String sql, [List<Object?> params = const []]) async {
    final conn = await connection;
    final result = await conn.execute(sql, params.isEmpty ? null : {
      for (int i = 0; i < params.length; i++) 'p$i': params[i],
    });
    return result.rows.map((r) => r.assoc()).toList();
  }

  Future<IResultSet> execute(String sql, [List<Object?> params = const []]) async {
    final conn = await connection;
    return await conn.execute(sql, params.isEmpty ? null : {
      for (int i = 0; i < params.length; i++) 'p$i': params[i],
    });
  }

  Future<void> close() async => await _conn?.close();
}