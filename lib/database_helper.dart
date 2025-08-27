// lib/database_helper.dart

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'main.dart'; // Importamos para ter acesso à classe Bebida

class DatabaseHelper {
  // Padrão Singleton para garantir que haverá apenas uma instância do banco.
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDB();

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'estoque.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Cria a tabela na primeira vez que o banco é criado.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bebidas (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        quantidade INTEGER NOT NULL
      )
    ''');
    // (Opcional) Popula o banco com dados iniciais
    //await _seedDatabase(db);
  }

  // (Opcional) Adiciona os itens iniciais para o app não começar vazio.
  // Future<void> _seedDatabase(Database db) async {
  //   final batch = db.batch();
  //   batch.insert('bebidas', {'id': 'vodka_abs', 'nome': 'Vodka Absolut', 'quantidade': 0});
  //   batch.insert('bebidas', {'id': 'gin_tanq', 'nome': 'Gin Tanqueray', 'quantidade': 0});
  //   batch.insert('bebidas', {'id': 'whisky_jw', 'nome': 'Whisky Johnnie Walker Red', 'quantidade': 0});
  //   batch.insert('bebidas', {'id': 'energetico_rb', 'nome': 'Energético Red Bull', 'quantidade': 0});
  //   batch.insert('bebidas', {'id': 'cerveja_h', 'nome': 'Cerveja Heineken', 'quantidade': 0});
  //   batch.insert('bebidas', {'id': 'refri_coca', 'nome': 'Refrigerante Coca-Cola', 'quantidade': 0});
  //   await batch.commit(noResult: true);
  // }
  
  // ----------- OPERAÇÕES CRUD (Create, Read, Update, Delete) -----------

  // Busca todas as bebidas do banco.
  Future<List<Bebida>> getAllBebidas() async {
    final db = await instance.database;
    final result = await db.query('bebidas', orderBy: 'nome ASC');
    return result.map((json) => Bebida.fromMap(json)).toList();
  }
  
  // Atualiza uma bebida existente.
  Future<int> updateBebida(Bebida bebida) async {
    final db = await instance.database;
    return await db.update(
      'bebidas',
      bebida.toMap(),
      where: 'id = ?',
      whereArgs: [bebida.id],
    );
  }

  // Insere uma nova bebida
  Future<int> insertBebida(Bebida bebida) async {
    final db = await instance.database;
    return await db.insert(
      'bebidas',
      bebida.toMap(),
      // Em caso de conflito de ID, substitui o antigo
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Deleta uma bebida pelo ID
  Future<int> deleteBebida(String id) async {
    final db = await instance.database;
    return await db.delete(
      'bebidas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}