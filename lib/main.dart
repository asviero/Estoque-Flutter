import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  runApp(const CasaNoturnaApp());
}

//----------- MODELO DE DADOS -----------
class Bebida {
  final String id;
  final String nome;
  int quantidade;

  Bebida({
    required this.id,
    required this.nome,
    this.quantidade = 0,
  });

  Map<String, dynamic> toMap() {
    return { 'id': id, 'nome': nome, 'quantidade': quantidade };
  }

  factory Bebida.fromMap(Map<String, dynamic> map) {
    return Bebida(
      id: map['id'],
      nome: map['nome'],
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
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1F1F1F)),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  DateTime _dataSelecionada = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refreshBebidasList();
    _tabController.addListener(_handleSelecaoDeAba);
  }

  void _handleSelecaoDeAba() {
    if (_tabController.indexIsChanging) return;
    setState(() { _indiceAbaAtual = _tabController.index; });
  }

  void _refreshBebidasList() {
    setState(() { _listaBebidas = dbHelper.getEstoqueParaData(_dataSelecionada); });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleSelecaoDeAba);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );
    if (dataEscolhida != null && dataEscolhida != _dataSelecionada) {
      setState(() { _dataSelecionada = dataEscolhida; });
      _refreshBebidasList();
    }
  }

  //----------- LÓGICA DE ESTOQUE -----------
  Future<void> _adicionarEstoque(Bebida bebida, int quantidade, String? observacao, bool isAjusteInicial) async {
    final tipoMovimentacao = isAjusteInicial ? 'Ajuste Inicial' : 'Entrada';
    await dbHelper.adicionarMovimentacao(
      bebidaId: bebida.id, data: _dataSelecionada, quantidade: quantidade, tipo: tipoMovimentacao, observacao: observacao,
    );
    _refreshBebidasList();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$quantidade un. de ${bebida.nome} adicionadas.'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _registrarSaida(Bebida bebida, int quantidade, String? observacao, bool isAjuste) async {
    final estoqueAtual = await dbHelper.getEstoqueParaData(_dataSelecionada)
        .then((lista) => lista.firstWhere((b) => b.id == bebida.id).quantidade);

    if (estoqueAtual >= quantidade) {
      await dbHelper.adicionarMovimentacao(
        bebidaId: bebida.id, data: _dataSelecionada, quantidade: -quantidade, tipo: 'Saída para Bar', observacao: observacao,
      );
      _refreshBebidasList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$quantidade un. de ${bebida.nome} saíram para o bar.'),
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
  
  Future<void> _registrarVenda(Bebida bebida, int quantidade, String? observacao, bool isAjuste) async {
    final estoqueAtual = await dbHelper.getEstoqueParaData(_dataSelecionada)
        .then((lista) => lista.firstWhere((b) => b.id == bebida.id).quantidade);

    if (estoqueAtual >= quantidade) {
      await dbHelper.adicionarMovimentacao(
        bebidaId: bebida.id, data: _dataSelecionada, quantidade: -quantidade, tipo: 'Venda', observacao: observacao,
      );
      _refreshBebidasList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$quantidade un. de ${bebida.nome} foram vendidas.'),
          backgroundColor: Colors.red.shade400,
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
  
  //----------- LÓGICA DO CATÁLOGO -----------
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
  
  //----------- DIÁLOGOS -----------
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
            onPressed: () {
              _removerBebida(bebida.id, bebida.nome);
              Navigator.of(ctx).pop();
            },
            child: const Text('Remover'),
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
  
  // PDF gera duas tabelas; um resumo e um detalhamento das saídas (saídas que contém observação).
  Future<void> _gerarRelatorioPDF() async {
    final pdf = pw.Document();
    final dataFormatada = DateFormat('dd/MM/yyyy', 'pt_BR').format(_dataSelecionada);
    
    // 1. Busca os dados para a tabela de resumo
    final dadosConsolidados = await dbHelper.getDadosRelatorioConsolidado(_dataSelecionada);
    // 2. Busca as movimentações individuais do dia para a tabela de detalhes
    final movimentacoesDoDia = await dbHelper.getMovimentacoesDoDia(_dataSelecionada);

    // Filtra apenas as saídas (Vendas e Saídas) para a segunda tabela
    final todasAsSaidas = movimentacoesDoDia
        .where((m) => (m['quantidade_alterada'] as int) < 0)
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        header: (context) => pw.Header(level: 0, text: 'Relatório de Estoque - $dataFormatada'),
        build: (context) => [
          pw.Header(level: 1, text: 'Resumo do Dia'),
          pw.TableHelper.fromTextArray(
            headers: [ 'Bebida', 'Est. Inicial', 'Vendas', 'Saídas p/ Bar', 'Est. Final' ],
            data: dadosConsolidados.map((dado) => [
              dado['nome'],
              dado['estoqueInicial'].toString(),
              dado['vendido'].toString(),
              dado['retiradoDoEstoque'].toString(),
              dado['estoqueFinal'].toString(),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignments: {
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
            },
            border: pw.TableBorder.all(),
          ),
          
          if (todasAsSaidas.isNotEmpty) ...[
            pw.SizedBox(height: 30),
            pw.Header(level: 1, text: 'Detalhes das Saídas do Dia'),
            pw.TableHelper.fromTextArray(
              headers: ['Qtd.', 'Bebida', 'Tipo', 'Observação'],
              data: todasAsSaidas.map((m) {
                final qtd = (m['quantidade_alterada'] as int).abs(); // Pega a quantidade positiva
                return [
                  qtd.toString(),
                  m['nome'],
                  m['tipo'],
                  m['observacao'] ?? '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignments: { 0: pw.Alignment.center, },
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(4),
              },
              border: pw.TableBorder.all(),
            ),
          ],
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
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
            Tab(icon: Icon(Icons.point_of_sale), text: 'Vendas'),
            Tab(icon: Icon(Icons.local_bar), text: 'Saída'),
            Tab(icon: Icon(Icons.assessment), text: 'Relatório'),
          ],
        ),
      ),
      body: FutureBuilder<List<Bebida>>(
        future: _listaBebidas,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
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
                  titulo: 'Registrar Venda Direta',
                  acao: _registrarVenda,
                  onRemover: _mostrarDialogoConfirmarRemocao,
                  corBotao: Colors.red.shade400,
                  textoBotao: 'Vendido',
                ),
                OperacaoEstoqueTab(
                  estoque: estoque,
                  titulo: 'Saída para os Bares',
                  acao: _registrarSaida,
                  onRemover: _mostrarDialogoConfirmarRemocao,
                  corBotao: Colors.orange,
                  textoBotao: 'Enviar',
                ),
                RelatorioTab(
                  estoque: estoque,
                  onRemover: _mostrarDialogoConfirmarRemocao,
                  onGerarPDF: _gerarRelatorioPDF,
                ),
              ],
            );
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));
          }
          return const Center(child: Text('Nenhuma bebida encontrada. Adicione uma no botão +'));
        },
      ),
      floatingActionButton: _indiceAbaAtual == 0 ? FloatingActionButton(
        onPressed: _mostrarDialogoAdicionarBebida,
        backgroundColor: Colors.indigo,
        tooltip: 'Adicionar nova bebida ao catálogo',
        child: const Icon(Icons.add_shopping_cart),
      ) : null,
    );
  }
}

//----------- WIDGETS DAS ABAS -----------
class OperacaoEstoqueTab extends StatelessWidget {
  final List<Bebida> estoque;
  final String titulo;
  final Function(Bebida, int, String?, bool) acao;
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
    final qtdController = TextEditingController();
    final obsController = TextEditingController();
    bool isAjusteInicial = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('$textoBotao ${bebida.nome}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: qtdController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Quantidade'),
                      keyboardType: TextInputType.number,
      
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: obsController,
                      decoration: const InputDecoration(labelText: 'Observação (Opcional)'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    if (titulo == 'Entrada no Estoque')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: CheckboxListTile(
                          title: const Text('Definir como Estoque Inicial', style: TextStyle(fontSize: 14)),
                          value: isAjusteInicial,
                          onChanged: (value) {
                            setDialogState(() {
                              isAjusteInicial = value ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                FilledButton(
                  child: Text(textoBotao),
                  onPressed: () {
                    final quantidade = int.tryParse(qtdController.text) ?? 0;
                    final observacao = obsController.text.trim().isEmpty ? null : obsController.text.trim();
                    if (quantidade > 0) {
                      acao(bebida, quantidade, observacao, isAjusteInicial);
                    }
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            );
          },
        );
      },
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
                    subtitle: Text('Estoque atual: ${bebida.quantidade}'),
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
  final VoidCallback onGerarPDF;

  const RelatorioTab({
    super.key,
    required this.estoque,
    required this.onRemover,
    required this.onGerarPDF,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Relatório do Dia',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ElevatedButton.icon(
                  onPressed: onGerarPDF,
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Gerar PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade400,
                    padding: const EdgeInsets.symmetric(horizontal: 16)
                  ),
                ),
              ),
            ],
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