import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const CasaNoturnaApp());
}

//----------- "Banco de Dados" -----------
class Bebida {
  final String id;
  final String nome;
  int quantidade;

  Bebida({required this.id, required this.nome, this.quantidade = 0});
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

  //----------- "Banco de Dados" temporário -----------
  final List<Bebida> _estoque = [
    Bebida(id: 'vodka_abs', nome: 'Absolut Vodka'),
    Bebida(id: 'vodma_smi', nome: 'Smirnoff Vodka'),
    Bebida(id: 'gin_tanq', nome: 'Gin Tanqueray'),
    Bebida(id: 'whisky_jw', nome: 'Whisky Johnnie Walker Red'),
    Bebida(id: 'energetico_rb', nome: 'Energético Red Bull'),
    Bebida(id: 'cerveja_h', nome: 'Cerveja Heineken'),
    Bebida(id: 'refri_coca', nome: 'Refrigerante Coca-Cola'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Função para adicionar itens ao estoque
  void _adicionarEstoque(String bebidaId, int quantidadeAdicionada) {
    setState(() {
      final bebida = _estoque.firstWhere((b) => b.id == bebidaId);
      bebida.quantidade += quantidadeAdicionada;
    });
    // Mostra uma mensagem de confirmação
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$quantidadeAdicionada un. de ${_estoque.firstWhere((b) => b.id == bebidaId).nome} adicionadas ao estoque.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Função para registrar saídas (vendas ou envio para o bar)
  void _registrarSaida(String bebidaId, int quantidadeRetirada, String motivo) {
    setState(() {
      final bebida = _estoque.firstWhere((b) => b.id == bebidaId);
      if (bebida.quantidade >= quantidadeRetirada) {
        bebida.quantidade -= quantidadeRetirada;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$quantidadeRetirada un. de ${bebida.nome} saíram do estoque ($motivo).'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estoque insuficiente para ${bebida.nome}.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
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
            Tab(icon: Icon(Icons.point_of_sale), text: 'Vendas'),
            Tab(icon: Icon(Icons.local_bar), text: 'Bares'),
            Tab(icon: Icon(Icons.assessment), text: 'Relatório'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Aba 1: Entrada de Estoque
          OperacaoEstoqueTab(
            estoque: _estoque,
            titulo: 'Adicionar ao Estoque',
            acao: _adicionarEstoque,
            corBotao: Colors.green,
            textoBotao: 'Adicionar',
          ),
          // Aba 2: Registrar Vendas
          OperacaoEstoqueTab(
            estoque: _estoque,
            titulo: 'Registrar Venda Direta',
            acao: (id, qtd) => _registrarSaida(id, qtd, 'Venda'),
            corBotao: Colors.red,
            textoBotao: 'Vendido',
          ),
          // Aba 3: Enviar para os Bares
          OperacaoEstoqueTab(
            estoque: _estoque,
            titulo: 'Enviar para os Bares',
            acao: (id, qtd) => _registrarSaida(id, qtd, 'Envio para Bar'),
            corBotao: Colors.orange,
            textoBotao: 'Enviar',
          ),
          // Aba 4: Relatório
          RelatorioTab(estoque: _estoque),
        ],
      ),
    );
  }
}

//----------- Widget reutilizável para as abas de operação -----------
class OperacaoEstoqueTab extends StatelessWidget {
  final List<Bebida> estoque;
  final String titulo;
  final Function(String, int) acao;
  final Color corBotao;
  final String textoBotao;

  const OperacaoEstoqueTab({
    super.key,
    required this.estoque,
    required this.titulo,
    required this.acao,
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
                acao(bebida.id, quantidade);
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
                    trailing: ElevatedButton(
                      onPressed: () => _mostrarDialogoDeQuantidade(context, bebida),
                      style: ElevatedButton.styleFrom(backgroundColor: corBotao),
                      child: Text(textoBotao),
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

  const RelatorioTab({super.key, required this.estoque});

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
                    trailing: Text(
                      bebida.quantidade.toString(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: bebida.quantidade < 10 ? Colors.red.shade400 : Colors.green.shade400
                      ),
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