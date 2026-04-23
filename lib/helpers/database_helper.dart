import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/bebidas.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDB();

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'estoque_v3.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bebidas (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE movimentacoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bebida_id TEXT NOT NULL,
        data TEXT NOT NULL,
        quantidade_alterada INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        observacao TEXT,
        FOREIGN KEY (bebida_id) REFERENCES bebidas (id) ON DELETE CASCADE
      )
    ''');
    await _seedBebidas(db);
  }

  Future<void> _seedBebidas(Database db) async {
    const bebidasIniciais = [
      'Absolut',
      'Smirnoff',
      'Black Label',
      'Chivas',
      'Jack Daniels',
      'Jack Fire',
      'Jack Honey',
      'Jack Apple',
      'Red Label',
      'Beefeater',
      "Seagram's",
      'Elyx 750mL',
      'Belvedere 700ml',
      'Grey Goose',
      'Grey Goose 1,5L',
      'Ballena',
      'Jagermeister',
      'Licor 43',
      'Fernet',
      'Macallan 12 Anos',
      'Royal Salute',
      'Tequila José Cuervo',
    ];
    final batch = db.batch();
    for (final nome in bebidasIniciais) {
      final id = nome
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r"[^a-z0-9_]"), '');
      batch.insert('bebidas', {'id': id, 'nome': nome});
    }
    await batch.commit(noResult: true);
  }

  Future<void> adicionarMovimentacao({
    required String bebidaId,
    required DateTime data,
    required int quantidade,
    required String tipo,
    String? observacao,
  }) async {
    final db = await database;
    await db.insert('movimentacoes', {
      'bebida_id': bebidaId,
      'data': _formatDate(data),
      'quantidade_alterada': quantidade,
      'tipo': tipo,
      'observacao': observacao,
    });
  }

  Future<int> getEstoqueAtualDaBebida(String bebidaId, DateTime data) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(quantidade_alterada), 0) as total FROM movimentacoes WHERE bebida_id = ? AND data <= ?',
      [bebidaId, _formatDate(data)],
    );
    return (result.first['total'] as num).toInt();
  }

  Future<List<Bebida>> getEstoqueParaData(DateTime data) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT b.id, b.nome, COALESCE(SUM(m.quantidade_alterada), 0) as quantidade
      FROM bebidas b
      LEFT JOIN movimentacoes m ON b.id = m.bebida_id AND m.data <= ?
      GROUP BY b.id, b.nome
      ORDER BY b.nome ASC
    ''',
      [_formatDate(data)],
    );
    return maps.map(Bebida.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getDadosRelatorioConsolidado(
    DateTime data,
  ) async {
    final db = await database;
    final dataFormatada = _formatDate(data);
    final result = await db.rawQuery(
      '''
      SELECT
        b.nome,
        b.id,
        COALESCE((
          SELECT SUM(quantidade_alterada) FROM movimentacoes
          WHERE bebida_id = b.id AND data < ?
        ), 0) as estoqueAnterior,
        COALESCE(SUM(CASE WHEN m.tipo = 'Venda' THEN m.quantidade_alterada END), 0) as vendido,
        COALESCE(SUM(CASE WHEN m.tipo = 'Saída para Bar' THEN m.quantidade_alterada END), 0) as retiradoDoEstoque,
        COALESCE(SUM(CASE WHEN m.tipo = 'Entrada' THEN m.quantidade_alterada END), 0) as entradasDoDia,
        COALESCE(SUM(CASE WHEN m.tipo = 'Ajuste Inicial' THEN m.quantidade_alterada END), 0) as ajusteInicialDoDia
      FROM bebidas b
      INNER JOIN movimentacoes m ON b.id = m.bebida_id AND m.data = ?
      GROUP BY b.id, b.nome
      ORDER BY b.nome ASC
    ''',
      [dataFormatada, dataFormatada],
    );

    final movimentacoesDoDia = await getMovimentacoesDoDia(data);

    return result.map((row) {
      final estoqueAnterior = (row['estoqueAnterior'] as num).toInt();
      final ajusteInicialDoDia = (row['ajusteInicialDoDia'] as num).toInt();
      final estoqueInicial = ajusteInicialDoDia > 0
          ? ajusteInicialDoDia
          : estoqueAnterior;

      final entradasDoDia = (row['entradasDoDia'] as num).toInt();
      final vendido = (row['vendido'] as num).toInt().abs();
      final retiradoDoEstoque = (row['retiradoDoEstoque'] as num).toInt().abs();
      final estoqueFinal =
          estoqueInicial + entradasDoDia - vendido - retiradoDoEstoque;

      final observacoes = movimentacoesDoDia
          .where((m) => m['nome'] == row['nome'] && m['observacao'] != null)
          .map((m) => m['observacao'] as String)
          .where((obs) => obs.isNotEmpty)
          .join('; ');

      return {
        'nome': row['nome'],
        'estoqueInicial': estoqueInicial,
        'vendido': vendido,
        'retiradoDoEstoque': retiradoDoEstoque,
        'observacao': observacoes,
        'estoqueFinal': estoqueFinal,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getMovimentacoesDoDia(
    DateTime data,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT b.nome, m.quantidade_alterada, m.tipo, m.observacao
      FROM movimentacoes m
      JOIN bebidas b ON m.bebida_id = b.id
      WHERE m.data = ?
      ORDER BY b.nome ASC, m.id ASC
    ''',
      [_formatDate(data)],
    );
  }

  Future<void> insertBebida(Bebida bebida) async {
    final db = await database;
    await db.insert('bebidas', {
      'id': bebida.id,
      'nome': bebida.nome,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBebida(String id) async {
    final db = await database;
    await db.delete('bebidas', where: 'id = ?', whereArgs: [id]);
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
}
