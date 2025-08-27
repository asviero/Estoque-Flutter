import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'database_helper.dart';

Future<void> main() async {
  // 2. Garante que o Flutter está inicializado antes de rodar código async
  WidgetsFlutterBinding.ensureInitialized(); 

  // 3. Carrega os dados de formatação para o nosso idioma (pt_BR)
  await initializeDateFormatting('pt_BR', null);

  runApp(const CasaNoturnaApp());
}

//----------- MODELO DE DADOS -----------
class Bebida {
  final String id;
  final String nome;
  int quantidade; // A quantidade agora representa o estoque para a data selecionada

  Bebida({
    required this.id,
    required this.nome,
    this.quantidade = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'quantidade': quantidade,
    };
  }

  factory Bebida.fromMap(Map<String, dynamic> map) {
    return Bebida(
      id: map['id'],
      nome: map['nome'],
      // O COALESCE no SQL garante que a quantidade nunca será nula
      quantidade: map['quantidade'] ?? 0,
    );
  }
}

//----------- WIDGET PRINCIPAL -----------
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

//----------- PÁGINA PRINCIPAL -----------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final dbHelper = DatabaseHelper.instance;
  late Future<List<Bebida>> _listaBebidas;
  int _indiceAbaAtual = 0;

  // Guarda a data selecionada para gerenciar o estoque.
  // Inicia com a data de hoje.
  DateTime _dataSelecionada = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshBebidasList(); // Carrega a lista inicial para a data de hoje
    _tabController.addListener(_handleSelecaoDeAba);
  }

  // Função para atualizar o estado com o índice da aba selecionada
void _handleSelecaoDeAba() {
  if (_tabController.indexIsChanging) return;
  setState(() {
    _indiceAbaAtual = _tabController.index;
  });
}

  // Recarrega a lista baseada na data selecionada.
  void _refreshBebidasList() {
    setState(() {
      _listaBebidas = dbHelper.getEstoqueParaData(_dataSelecionada);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleSelecaoDeAba);
    _tabController.dispose();
    super.dispose();
  }

  // Função para abrir o calendário e selecionar uma data.
  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'), // Para traduzir o calendário
    );
    if (dataEscolhida != null && dataEscolhida != _dataSelecionada) {
      setState(() {
        _dataSelecionada = dataEscolhida;
      });
      _refreshBebidasList(); // Recarrega o estoque para a nova data
    }
  }

  //----------- LÓGICA DE ESTOQUE MODIFICADA PARA USAR A DATA SELECIONADA -----------

  Future<void> _adicionarEstoque(Bebida bebida, int quantidadeAdicionada) async {
    final novaQuantidade = bebida.quantidade + quantidadeAdicionada;
    await dbHelper.updateEstoqueParaData(bebida.id, novaQuantidade, _dataSelecionada);
    _refreshBebidasList();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$quantidadeAdicionada un. de ${bebida.nome} adicionadas.'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _registrarSaida(Bebida bebida, int quantidadeRetirada) async {
    if (bebida.quantidade >= quantidadeRetirada) {
      final novaQuantidade = bebida.quantidade - quantidadeRetirada;
      await dbHelper.updateEstoqueParaData(bebida.id, novaQuantidade, _dataSelecionada);
      _refreshBebidasList();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$quantidadeRetirada un. de ${bebida.nome} saíram do estoque.'),
            backgroundColor: Colors.orange,
            ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Estoque insuficiente para ${bebida.nome}.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
  
  Future<void> _adicionarNovaBebida(String nome) async {
    if (nome.trim().isEmpty) return;
    final id = nome.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final novaBebida = Bebida(id: id, nome: nome);
    await dbHelper.insertBebida(novaBebida);
    _refreshBebidasList();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${novaBebida.nome} adicionado(a) ao catálogo.'),
        backgroundColor: Colors.blue,
      ));
    }
  }

  Future<void> _removerBebida(String id, String nome) async {
    await dbHelper.deleteBebida(id);
    _refreshBebidasList();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$nome removido(a) do catálogo.'),
        backgroundColor: Colors.red,
      ));
    }
  }
  
  void _mostrarDialogoConfirmarRemocao(Bebida bebida) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text('Tem certeza que deseja remover ${bebida.nome} do catálogo? Todo o histórico de estoque será perdido.'),
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

  void _mostrarDialogoAdicionarBebida() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Nova Bebida ao Catálogo'),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gestão de Estoque'),
            Text(
              DateFormat('EEEE, dd/MM/yyyy', 'pt_BR').format(_dataSelecionada),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selecionarData(context),
            tooltip: 'Selecionar Data',
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_shopping_cart), text: 'Entrada'),
            Tab(icon: Icon(Icons.local_bar), text: 'Saída'),
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
            return TabBarView(
              controller: _tabController,
              children: [
                OperacaoEstoqueTab(
                  estoque: estoque,
                  titulo: 'Entrada no Estoque',
                  acao: _adicionarEstoque,
                  onRemover: _mostrarDialogoConfirmarRemocao,
                  corBotao: Colors.green,
                  textoBotao: 'Adicionar',
                ),
                OperacaoEstoqueTab(
                  estoque: estoque,
                  titulo: 'Saída do Estoque',
                  acao: _registrarSaida, // Passa a função diretamente
                  onRemover: _mostrarDialogoConfirmarRemocao,
                  corBotao: Colors.orange,
                  textoBotao: 'Enviar',
                ),
                RelatorioTab(
                  estoque: estoque,
                  onRemover: _mostrarDialogoConfirmarRemocao,
                ),
              ],
            );
          }
          return const Center(child: Text('Nenhuma bebida encontrada. Adicione uma no botão +'));
        },
      ),
      floatingActionButton: _indiceAbaAtual == 0 ? FloatingActionButton(
        onPressed: _mostrarDialogoAdicionarBebida,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add_shopping_cart),
        tooltip: 'Adicionar nova bebida ao catálogo',
      ) : null,
    );
  }
}

//----------- WIDGETS DAS ABAS -----------
class OperacaoEstoqueTab extends StatelessWidget {
  final List<Bebida> estoque;
  final String titulo;
  final Function(Bebida, int) acao;
  final Function(Bebida) onRemover;
  final Color corBotao;
  final String textoBotao;

  const OperacaoEstoqueTab({
    super.key,
    required this.estoque,
    required this.titulo,
    required this.acao,
    required this.onRemover,
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
                    subtitle: Text('Estoque do dia: ${bebida.quantidade}'),
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

class RelatorioTab extends StatelessWidget {
  final List<Bebida> estoque;
  final Function(Bebida) onRemover;

  const RelatorioTab({
    super.key,
    required this.estoque,
    required this.onRemover,
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
              'Relatório do Dia',
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