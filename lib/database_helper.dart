// lib/database_helper.dart

import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'main.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDB();

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'estoque_v3.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabela 1: Catálogo de bebidas
    await db.execute('''
      CREATE TABLE bebidas (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL
      )
    ''');

    // Tabela 2: Registro de cada movimentação de estoque
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
  
  // Lista inicial de bebidas
  Future<void> _seedBebidas(Database db) async {
    final List<String> bebidasIniciais = [
      'Absolut', 'Ballena', 'Beefeater', 'Beefeater Pink', 'Belvedere 700ml', 'Black Label', 'Chandon', 'Chandon 1,5L Brut', 'Chivas',
      'Elyx 1,750L', 'Elyx 4,5L', 'Elyx 750mL', 'Fernet', 'Grey Goose', 'Grey Goose 1,5L', 'Jack Apple', 'Jack Daniels', 'Jack Fire',
      'Jack Honey', 'Jaegermaister', 'Licor 43', 'Red Label', 'Salton Brut', 'Salton Brut Rosé', 'Salton Moscatel', 'Seagram\'s', 'Smirnoff',
      'Tequila', 'Veuve Clicquot',
    ];

    final batch = db.batch();
    for (final nome in bebidasIniciais) {
      final id = nome.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
      batch.insert('bebidas', {'id': id, 'nome': nome});
    }
    await batch.commit(noResult: true);
  }
  
  // ----------- OPERAÇÕES NO BANCO -----------
  Future<void> adicionarMovimentacao({ required String bebidaId, required DateTime data, required int quantidade, required String tipo, String? observacao }) async {
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

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        b.id,
        b.nome,
        COALESCE(SUM(m.quantidade_alterada), 0) as quantidade
      FROM bebidas b
      LEFT JOIN movimentacoes m ON b.id = m.bebida_id AND m.data <= ?
      GROUP BY b.id, b.nome
      ORDER BY b.nome ASC
    ''', [dataFormatada]);
    
    return List.generate(maps.length, (i) => Bebida.fromMap(maps[i]));
  }

  Future<List<Map<String, dynamic>>> getDadosRelatorioConsolidado(DateTime data) async {
    final db = await instance.database;
    final dataFormatada = DateFormat('yyyy-MM-dd').format(data);
    final dataAnterior = DateFormat('yyyy-MM-dd').format(data.subtract(const Duration(days: 1)));

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        b.nome,
        b.id,
        -- Estoque Inicial "real" é tudo que aconteceu ANTES de hoje.
        COALESCE((SELECT SUM(quantidade_alterada) FROM movimentacoes WHERE bebida_id = b.id AND data < ?), 0) as estoqueAnterior,
        -- Soma das Vendas do dia
        COALESCE(SUM(CASE WHEN m.tipo = 'Venda' THEN m.quantidade_alterada END), 0) as vendido,
        -- Soma das Saídas para Bar do dia
        COALESCE(SUM(CASE WHEN m.tipo = 'Saída para Bar' THEN m.quantidade_alterada END), 0) as retiradoDoEstoque,
        -- Soma das Entradas NORMAIS do dia
        COALESCE(SUM(CASE WHEN m.tipo = 'Entrada' THEN m.quantidade_alterada END), 0) as entradasDoDia,
        -- Pega o valor do Ajuste Inicial do dia, se houver
        COALESCE(SUM(CASE WHEN m.tipo = 'Ajuste Inicial' THEN m.quantidade_alterada END), 0) as ajusteInicialDoDia
      FROM bebidas b
      LEFT JOIN movimentacoes m ON b.id = m.bebida_id AND m.data = ?
      GROUP BY b.id, b.nome
      ORDER BY b.nome ASC
    ''', [dataAnterior, dataFormatada]);

    return result.map((row) {
      final estoqueAnterior = row['estoqueAnterior'] as int;
      final ajusteInicialDoDia = row['ajusteInicialDoDia'] as int;
      
      // O estoque inicial do dia é o que sobrou de ontem OU o ajuste que foi feito hoje.
      final estoqueInicial = (ajusteInicialDoDia > 0) ? ajusteInicialDoDia : estoqueAnterior;

      final entradasDoDia = row['entradasDoDia'] as int;
      final vendido = (row['vendido'] as int).abs();
      final retiradoDoEstoque = (row['retiradoDoEstoque'] as int).abs();
      final estoqueFinal = estoqueInicial + entradasDoDia - vendido - retiradoDoEstoque;
      
      return {
        'nome': row['nome'],
        'estoqueInicial': estoqueInicial,
        'vendido': vendido,
        'retiradoDoEstoque': retiradoDoEstoque,
        'estoqueFinal': estoqueFinal,
      };
    }).toList();
  }
  
  Future<List<Map<String, dynamic>>> getMovimentacoesDoDia(DateTime data) async {
    final db = await instance.database;
    final dataFormatada = DateFormat('yyyy-MM-dd').format(data);
    final result = await db.rawQuery('''
      SELECT b.nome, m.quantidade_alterada, m.tipo, m.observacao
      FROM movimentacoes m
      JOIN bebidas b ON m.bebida_id = b.id
      WHERE m.data = ?
      ORDER BY b.nome ASC, m.id ASC
    ''', [dataFormatada]);
    return result;
  }

  // Funções para gerenciar o catálogo de bebidas
  Future<int> insertBebida(Bebida bebida) async {
    final db = await instance.database;
    return await db.insert('bebidas', {'id': bebida.id, 'nome': bebida.nome},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteBebida(String id) async {
    final db = await instance.database;
    return await db.delete('bebidas', where: 'id = ?', whereArgs: [id]);
  }
}