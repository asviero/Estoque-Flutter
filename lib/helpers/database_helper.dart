import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:viero_stock/models/bebidas.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDB();

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'estoque.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
    await db.execute('''
      CREATE TABLE consumo_staff (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        categoria TEXT NOT NULL,
        item TEXT NOT NULL,
        quantidade INTEGER NOT NULL,
        observacao TEXT
      )
    ''');
    await _seedBebidas(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE consumo_staff (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          data TEXT NOT NULL,
          categoria TEXT NOT NULL,
          item TEXT NOT NULL,
          quantidade INTEGER NOT NULL,
          observacao TEXT
        )
      ''');
    }
  }

  Future<void> _seedBebidas(Database db) async {
    const bebidasIniciais = [
      'Absolut',
      'Ballena',
      'Beefeater',
      'Beefeater Pink',
      'Belvedere 700ml',
      'Black Label',
      'Chandon 1,5L',
      'Chandon 750ml',
      'Chandon Spritz',
      'Chivas',
      'Elyx 750mL',
      'Fernet',
      'Grey Goose',
      'Grey Goose 1,5L',
      'Jack Apple',
      'Jack Blackberry',
      'Jack Daniels',
      'Jack Fire',
      'Jack Honey',
      'Jagermeister',
      'Licor 43',
      'Macallan 12 Anos',
      'Miolo Reserva',
      'Miolo Rosè',
      'Red Label',
      'Royal Salute',
      'Salton Moscatel',
      'Salton Brut',
      'Saltou Brut Rosé',
      "Seagram's",
      'Smirnoff',
      'Tequila José Cuervo',
    ];
    final batch = db.batch();
    for (final nome in bebidasIniciais) {
      final id = nome
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
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

  Future<void> insertConsumoStaff({
    required DateTime data,
    required String categoria,
    required String item,
    required int quantidade,
    String? observacao,
  }) async {
    final db = await database;
    await db.insert('consumo_staff', {
      'data': _formatDate(data),
      'categoria': categoria,
      'item': item,
      'quantidade': quantidade,
      'observacao': observacao,
    });
  }

  Future<List<Map<String, dynamic>>> getConsumoStaffDoDia(DateTime data) async {
    final db = await database;
    return db.query(
      'consumo_staff',
      where: 'data = ?',
      whereArgs: [_formatDate(data)],
      orderBy: 'categoria ASC, id ASC',
    );
  }

  Future<void> deleteConsumoStaff(int id) async {
    final db = await database;
    await db.delete('consumo_staff', where: 'id = ?', whereArgs: [id]);
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
}
