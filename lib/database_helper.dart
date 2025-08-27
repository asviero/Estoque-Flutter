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
    String path = join(await getDatabasesPath(), 'estoque_v2.db'); // NOVO NOME para forçar recriação
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // ALTERADO: A estrutura do banco de dados mudou completamente.
  Future<void> _onCreate(Database db, int version) async {
    // Tabela 1: Apenas o catálogo de bebidas
    await db.execute('''
      CREATE TABLE bebidas (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL
      )
    ''');

    // Tabela 2: O histórico de estoque para cada bebida em cada dia
    await db.execute('''
      CREATE TABLE estoque_diario (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bebida_id TEXT NOT NULL,
        data TEXT NOT NULL,
        quantidade INTEGER NOT NULL,
        FOREIGN KEY (bebida_id) REFERENCES bebidas (id) ON DELETE CASCADE,
        UNIQUE (bebida_id, data)
      )
    ''');
    
    await _seedBebidas(db); // Popula apenas a lista de bebidas
  }
  
  // ALTERADO: Esta função agora só insere o catálogo de bebidas, sem quantidade.
  Future<void> _seedBebidas(Database db) async {
    final List<String> bebidasIniciais = [
      'Absolut', 'Ballena', 'Beefeater', 'Beefeater Pink', 'Belvedere 700ml',
      'Black Label', 'Chandon', 'Chandon 1,5L Brut', 'Chivas', 'Elyx 1,750L',
      'Elyx 4,5L', 'Elyx 750mL', 'Fernet', 'Grey Goose', 'Grey Goose 1,5L',
      'Jack Apple', 'Jack Daniels', 'Jack Fire', 'Jack Honey', 'Jaegermaister',
      'Licor 43', 'Red Label', 'Salton Brut', 'Salton Brut Rosé', 'Salton Moscatel',
      'Seagram\'s', 'Smirnoff', 'Tequila', 'Veuve Clicquot',
    ];

    final batch = db.batch();
    for (final nome in bebidasIniciais) {
      final id = nome.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
      batch.insert('bebidas', {'id': id, 'nome': nome});
    }
    await batch.commit(noResult: true);
  }
  
  // ----------- NOVAS OPERAÇÕES CRUD -----------

  // NOVO: Busca o estoque de todas as bebidas para UMA DATA ESPECÍFICA.
  Future<List<Bebida>> getEstoqueParaData(DateTime data) async {
    final db = await instance.database;
    final dataFormatada = DateFormat('yyyy-MM-dd').format(data);

    // Usamos um LEFT JOIN para garantir que todas as bebidas sejam listadas,
    // mesmo que não tenham uma entrada de estoque para o dia selecionado.
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        b.id,
        b.nome,
        COALESCE(e.quantidade, 0) as quantidade
      FROM bebidas b
      LEFT JOIN estoque_diario e ON b.id = e.bebida_id AND e.data = ?
      ORDER BY b.nome ASC
    ''', [dataFormatada]);
    
    return List.generate(maps.length, (i) => Bebida.fromMap(maps[i]));
  }

  // NOVO: Atualiza ou insere (UPSERT) a quantidade de uma bebida para uma data.
  Future<void> updateEstoqueParaData(String bebidaId, int novaQuantidade, DateTime data) async {
    final db = await instance.database;
    final dataFormatada = DateFormat('yyyy-MM-dd').format(data);

    await db.transaction((txn) async {
      int count = await txn.update(
        'estoque_diario',
        {'quantidade': novaQuantidade},
        where: 'bebida_id = ? AND data = ?',
        whereArgs: [bebidaId, dataFormatada],
      );
      // Se nenhuma linha foi atualizada, significa que não existe, então inserimos.
      if (count == 0) {
        await txn.insert('estoque_diario', {
          'bebida_id': bebidaId,
          'data': dataFormatada,
          'quantidade': novaQuantidade,
        });
      }
    });
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