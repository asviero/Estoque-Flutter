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
    String path = join(await getDatabasesPath(), 'estoque_v3.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
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
    final List<String> bebidasIniciais = [
      'Absolut',
      'Ballena',
      'Beefeater',
      'Beefeater Pink',
      'Belvedere 700ml',
      'Black Label',
      'Chandon',
      'Chandon 1,5L Brut',
      'Chivas',
      'Elyx 1,750L',
      'Elyx 4,5L',
      'Elyx 750mL',
      'Fernet',
      'Grey Goose',
      'Grey Goose 1,5L',
      'Jack Apple',
      'Jack Daniels',
      'Jack Fire',
      'Jack Honey',
      'Jaegermaister',
      'Licor 43',
      'Red Label',
      'Salton Brut',
      'Salton Brut Rosé',
      'Salton Moscatel',
      'Seagram\'s',
      'Smirnoff',
      'Tequila',
      'Veuve Clicquot',
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
    final db = await instance.database;
    final dataFormatada = DateFormat('yyyy-MM-dd').format(data);
    await db.insert('movimentacoes', {
      'bebida_id': bebidaId,
      'data': dataFormatada,
      'quantidade_alterada': quantidade,
      'tipo': tipo,
      'observacao': observacao,
    });
  }

  Future<List<Bebida>> getEstoqueParaData(DateTime data) async {
    final db = await instance.database;
    final dataFormatada = DateFormat('yyyy-MM-dd').format(data);
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT b.id, b.nome, COALESCE(SUM(m.quantidade_alterada), 0) as quantidade
      FROM bebidas b
      LEFT JOIN movimentacoes m ON b.id = m.bebida_id AND m.data <= ?
      GROUP BY b.id, b.nome ORDER BY b.nome ASC
    ''',
      [dataFormatada],
    );
    return List.generate(maps.length, (i) => Bebida.fromMap(maps[i]));
  }

  Future<List<Map<String, dynamic>>> getDadosRelatorioConsolidado(
    DateTime data,
  ) async {
    final db = await instance.database;
    final dataFormatada = DateFormat('yyyy-MM-dd').format(data);
    final dataAnterior = DateFormat(
      'yyyy-MM-dd',
    ).format(data.subtract(const Duration(days: 1)));

    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT
        b.nome,
        b.id,
        COALESCE((SELECT SUM(quantidade_alterada) FROM movimentacoes WHERE bebida_id = b.id AND data < ?), 0) as estoqueAnterior,
        COALESCE(SUM(CASE WHEN m.tipo = 'Venda' THEN m.quantidade_alterada END), 0) as vendido,
        
        -- NOVO: Separação dos tipos de saída
        COALESCE(SUM(CASE WHEN m.tipo = 'Saída - Drinks' THEN m.quantidade_alterada END), 0) as saidaDrinks,
        COALESCE(SUM(CASE WHEN m.tipo = 'Saída - Doses' THEN m.quantidade_alterada END), 0) as saidaDoses,
        COALESCE(SUM(CASE WHEN m.tipo = 'Saída - Outro Bar' THEN m.quantidade_alterada END), 0) as saidaOutroBar,

        COALESCE(SUM(CASE WHEN m.tipo = 'Entrada' THEN m.quantidade_alterada END), 0) as entradasDoDia,
        COALESCE(SUM(CASE WHEN m.tipo = 'Ajuste Inicial' THEN m.quantidade_alterada END), 0) as ajusteInicialDoDia
      FROM bebidas b
      LEFT JOIN movimentacoes m ON b.id = m.bebida_id AND m.data = ?
      GROUP BY b.id, b.nome
      ORDER BY b.nome ASC
    ''',
      [dataAnterior, dataFormatada],
    );

    final movimentacoesDoDia = await getMovimentacoesDoDia(data);
    return result.map((row) {
      final estoqueAnterior = row['estoqueAnterior'] as int;
      final ajusteInicialDoDia = row['ajusteInicialDoDia'] as int;
      final estoqueInicial =
          (ajusteInicialDoDia != 0 && ajusteInicialDoDia > estoqueAnterior)
          ? ajusteInicialDoDia
          : estoqueAnterior;

      final entradasDoDia = row['entradasDoDia'] as int;
      final vendido = (row['vendido'] as int).abs();

      final saidaDrinks = (row['saidaDrinks'] as int).abs();
      final saidaDoses = (row['saidaDoses'] as int).abs();
      final saidaOutroBar = (row['saidaOutroBar'] as int).abs();

      final estoqueFinal =
          estoqueInicial +
          entradasDoDia -
          vendido -
          saidaDrinks -
          saidaDoses -
          saidaOutroBar;

      final observacoes = movimentacoesDoDia
          .where((m) => m['nome'] == row['nome'] && m['observacao'] != null)
          .map((m) => m['observacao'] as String)
          .where((obs) => obs.isNotEmpty)
          .join('; ');

      return {
        'nome': row['nome'],
        'estoqueInicial': estoqueInicial,
        'vendido': vendido,
        'saidaDrinks': saidaDrinks,
        'saidaDoses': saidaDoses,
        'saidaOutroBar': saidaOutroBar,
        'observacao': observacoes,
        'estoqueFinal': estoqueFinal,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getMovimentacoesDoDia(
    DateTime data,
  ) async {
    final db = await instance.database;
    final dataFormatada = DateFormat('yyyy-MM-dd').format(data);
    final result = await db.rawQuery(
      '''
      SELECT b.nome, m.quantidade_alterada, m.tipo, m.observacao
      FROM movimentacoes m
      JOIN bebidas b ON m.bebida_id = b.id
      WHERE m.data = ?
      ORDER BY b.nome ASC, m.id ASC
    ''',
      [dataFormatada],
    );
    return result;
  }

  Future<int> insertBebida(Bebida bebida) async {
    final db = await instance.database;
    return await db.insert('bebidas', {
      'id': bebida.id,
      'nome': bebida.nome,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteBebida(String id) async {
    final db = await instance.database;
    return await db.delete('bebidas', where: 'id = ?', whereArgs: [id]);
  }
}
