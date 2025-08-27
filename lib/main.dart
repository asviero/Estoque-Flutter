import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'database_helper.dart';

void main() {
  runApp(const CasaNoturnaApp());
}

//----------- "Banco de Dados" -----------
class Bebida {
  final String id;
  final String nome;
  int quantidade;

  Bebida({
    required this.id,
    required this.nome,
    this.quantidade = 0,
  });

  // Converte um objeto Bebida em um Map. As chaves devem corresponder
  // aos nomes das colunas no banco de dados.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'quantidade': quantidade,
    };
  }

  // Construtor extra para criar uma Bebida a partir de um Map vindo do banco.
  factory Bebida.fromMap(Map<String, dynamic> map) {
    return Bebida(
      id: map['id'],
      nome: map['nome'],
      quantidade: map['quantidade'],
    );
  }
}

//----------- Widget Principal -----------
class CasaNoturnaApp extends StatelessWidget {
  const CasaNoturnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle de Estoque',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

//----------- Página Principal -----------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final dbHelper = DatabaseHelper.instance; // Instância do nosso helper

  late Future<List<Bebida>> _listaBebidas;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshBebidasList(); // Carrega a lista inicial de bebidas
  }

  // Função para recarregar a lista do banco de dados e atualizar a tela
  void _refreshBebidasList() {
    setState(() {
      _listaBebidas = dbHelper.getAllBebidas();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  //----------- AS FUNÇÕES DE LÓGICA -----------

  Future<void> _adicionarEstoque(Bebida bebida, int quantidadeAdicionada) async {
    bebida.quantidade += quantidadeAdicionada;
    await dbHelper.updateBebida(bebida); // Atualiza no banco
    _refreshBebidasList(); // Recarrega a lista para a UI

    // Mostra a mensagem de confirmação
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$quantidadeAdicionada un. de ${bebida.nome} adicionadas ao estoque.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _registrarSaida(Bebida bebida, int quantidadeRetirada, String motivo) async {
    if (bebida.quantidade >= quantidadeRetirada) {
      bebida.quantidade -= quantidadeRetirada;
      await dbHelper.updateBebida(bebida); // Atualiza no banco
      _refreshBebidasList(); // Recarrega a lista para a UI

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$quantidadeRetirada un. de ${bebida.nome} saíram do estoque ($motivo).'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estoque insuficiente para ${bebida.nome}.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // NOVO: Função para adicionar uma nova bebida ao banco de dados.
  Future<void> _adicionarNovaBebida(String nome) async {
    if (nome.trim().isEmpty) return;

    // Cria um ID único simples a partir do nome
    final id = nome.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');

    final novaBebida = Bebida(id: id, nome: nome, quantidade: 0);
    await dbHelper.insertBebida(novaBebida);
    _refreshBebidasList();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${novaBebida.nome} adicionado(a) ao estoque.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  // NOVO: Função para remover uma bebida do banco.
  Future<void> _removerBebida(String id, String nome) async {
    await dbHelper.deleteBebida(id);
    _refreshBebidasList();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$nome removido(a) do estoque.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // NOVO: Diálogo para confirmar a remoção.
  void _mostrarDialogoConfirmarRemocao(Bebida bebida) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text('Tem certeza que deseja remover ${bebida.nome} do estoque? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade900),
            child: const Text('Remover'),
            onPressed: () {
              _removerBebida(bebida.id, bebida.nome);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  // NOVO: Diálogo para adicionar uma nova bebida.
  void _mostrarDialogoAdicionarBebida() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Nova Bebida'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da Bebida'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton(
            child: const Text('Salvar'),
            onPressed: () {
              _adicionarNovaBebida(controller.text);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Estoque'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_shopping_cart), text: 'Entrada'),
            Tab(icon: Icon(Icons.local_bar), text: 'Bares'),
            Tab(icon: Icon(Icons.assessment), text: 'Relatório'),
          ],
        ),
      ),
      body: FutureBuilder<List<Bebida>>(
        future: _listaBebidas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          else if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));
          }
          else if (snapshot.hasData) {
            final estoque = snapshot.data!;
            // ALTERADO: Passando a função de remover para as abas
            return TabBarView(
              controller: _tabController,
              children: [
                OperacaoEstoqueTab(
                  estoque: estoque,
                  titulo: 'Adicionar ao Estoque',
                  acao: _adicionarEstoque,
                  onRemover: _mostrarDialogoConfirmarRemocao,
                  corBotao: Colors.green,
                  textoBotao: 'Adicionar',
                ),
                OperacaoEstoqueTab(
                  estoque: estoque,
                  titulo: 'Enviar para os Bares',
                  acao: (bebida, qtd) => _registrarSaida(bebida, qtd, 'Envio para Bar'),
                  onRemover: _mostrarDialogoConfirmarRemocao, // ALTERADO
                  corBotao: Colors.orange,
                  textoBotao: 'Enviar',
                ),
                RelatorioTab(
                  estoque: estoque,
                  onRemover: _mostrarDialogoConfirmarRemocao, // ALTERADO
                ),
              ],
            );
          }
          return const Center(child: Text('Nenhuma bebida encontrada. Adicione uma no botão +'));
        },
      ),
      // NOVO: Botão flutuante para adicionar novas bebidas
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoAdicionarBebida,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add),
      ),
    );
  }
}

//----------- Widget para as abas de operação -----------
class OperacaoEstoqueTab extends StatelessWidget {
  final List<Bebida> estoque;
  final String titulo;
  final Function(Bebida, int) acao;
  final Function(Bebida) onRemover; // ALTERADO
  final Color corBotao;
  final String textoBotao;

  const OperacaoEstoqueTab({
    super.key,
    required this.estoque,
    required this.titulo,
    required this.acao,
    required this.onRemover, // ALTERADO
    required this.corBotao,
    required this.textoBotao,
  });

  void _mostrarDialogoDeQuantidade(BuildContext context, Bebida bebida) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$textoBotao ${bebida.nome}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Quantidade'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton(
            child: Text(textoBotao),
            onPressed: () {
              final quantidade = int.tryParse(controller.text) ?? 0;
              if (quantidade > 0) {
                acao(bebida, quantidade);
              }
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              titulo,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: estoque.length,
              itemBuilder: (ctx, index) {
                final bebida = estoque[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: ListTile(
                    title: Text(bebida.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Em estoque: ${bebida.quantidade}'),
                    // ALTERADO: Adicionamos o botão de remover
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => _mostrarDialogoDeQuantidade(context, bebida),
                          style: ElevatedButton.styleFrom(backgroundColor: corBotao),
                          child: Text(textoBotao),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_forever, color: Colors.red.shade400),
                          onPressed: () => onRemover(bebida),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

//----------- Widget para a aba de relatório -----------
class RelatorioTab extends StatelessWidget {
  final List<Bebida> estoque;
  final Function(Bebida) onRemover; // ALTERADO

  const RelatorioTab({
    super.key,
    required this.estoque,
    required this.onRemover, // ALTERADO
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Relatório de Estoque Atual',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: estoque.length,
              itemBuilder: (ctx, index) {
                final bebida = estoque[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: bebida.quantidade < 10 ? Colors.red.shade700 : Colors.green.shade700,
                      child: const Icon(Icons.liquor),
                    ),
                    title: Text(bebida.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bebida.quantidade.toString(),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: bebida.quantidade < 10 ? Colors.red.shade400 : Colors.green.shade400
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(Icons.delete_forever, color: Colors.red.shade400),
                          onPressed: () => onRemover(bebida),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}