import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../helpers/database_helper.dart';
import '../models/bebidas.dart';
import '../widgets/operacao_estoque_tab.dart';
import '../widgets/relatorio_tab.dart';
import '../widgets/saida_estoque_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final dbHelper = DatabaseHelper.instance;
  Future<List<Bebida>>? _listaBebidas;
  int _indiceAbaAtual = 0;

  DateTime? _dataSelecionada;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleSelecaoDeAba);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selecionarData(context, isInitialSelection: true);
    });
  }

  void _handleSelecaoDeAba() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _indiceAbaAtual = _tabController.index;
    });
  }

  void _refreshBebidasList() {
    if (_dataSelecionada != null) {
      setState(() {
        _listaBebidas = dbHelper.getEstoqueParaData(_dataSelecionada!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleSelecaoDeAba);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(
    BuildContext context, {
    bool isInitialSelection = false,
  }) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );

    if (dataEscolhida != null) {
      if (mounted) {
        setState(() {
          _dataSelecionada = dataEscolhida;
        });
      }
    } else if (isInitialSelection && _dataSelecionada == null) {
      if (mounted) {
        setState(() {
          _dataSelecionada = DateTime.now();
        });
      }
    }

    _refreshBebidasList();
  }

  Future<void> _adicionarEstoque(
    Bebida bebida,
    int quantidade,
    String? observacao,
    bool isAjusteInicial,
  ) async {
    final tipoMovimentacao = isAjusteInicial ? 'Ajuste Inicial' : 'Entrada';
    await dbHelper.adicionarMovimentacao(
      bebidaId: bebida.id,
      data: _dataSelecionada!,
      quantidade: quantidade,
      tipo: tipoMovimentacao,
      observacao: observacao,
    );
    _refreshBebidasList();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$quantidade un. de ${bebida.nome} adicionadas.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _registrarSaida(
    Bebida bebida,
    int quantidade,
    String? observacao,
    String motivo,
  ) async {
    final estoqueAtual = await dbHelper
        .getEstoqueParaData(_dataSelecionada!)
        .then((lista) => lista.firstWhere((b) => b.id == bebida.id).quantidade);

    if (estoqueAtual >= quantidade) {
      await dbHelper.adicionarMovimentacao(
        bebidaId: bebida.id,
        data: _dataSelecionada!,
        quantidade: -quantidade,
        tipo: motivo,
        observacao: observacao,
      );
      _refreshBebidasList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$quantidade un. de ${bebida.nome} saíram do estoque.',
            ),
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

  Future<void> _registrarVenda(
    Bebida bebida,
    int quantidade,
    String? observacao,
    bool isAjuste,
  ) async {
    final estoqueAtual = await dbHelper
        .getEstoqueParaData(_dataSelecionada!)
        .then((lista) => lista.firstWhere((b) => b.id == bebida.id).quantidade);

    if (estoqueAtual >= quantidade) {
      await dbHelper.adicionarMovimentacao(
        bebidaId: bebida.id,
        data: _dataSelecionada!,
        quantidade: -quantidade,
        tipo: 'Venda',
        observacao: observacao,
      );
      _refreshBebidasList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$quantidade un. de ${bebida.nome} foram vendidas.'),
            backgroundColor: Colors.red.shade400,
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

  Future<void> _adicionarNovaBebida(String nome) async {
    if (nome.trim().isEmpty) return;
    final id = nome
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final novaBebida = Bebida(id: id, nome: nome);
    await dbHelper.insertBebida(novaBebida);
    _refreshBebidasList();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${novaBebida.nome} adicionado(a) ao catálogo.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _removerBebida(String id, String nome) async {
    await dbHelper.deleteBebida(id);
    _refreshBebidasList();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$nome removido(a) do catálogo.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarDialogoConfirmarRemocao(Bebida bebida) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text(
          'Tem certeza que deseja remover ${bebida.nome} do catálogo? Todo o histórico de estoque será perdido.',
        ),
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

  Future<void> _gerarRelatorioPDF() async {
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(boldFontData);

    final pdf = pw.Document();
    final dataFormatada = DateFormat(
      'dd/MM/yyyy',
      'pt_BR',
    ).format(_dataSelecionada!);

    final dadosConsolidados = await dbHelper.getDadosRelatorioConsolidado(
      _dataSelecionada!,
    );
    final movimentacoesDoDia = await dbHelper.getMovimentacoesDoDia(
      _dataSelecionada!,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        header: (context) => pw.Header(
          level: 0,
          child: pw.Text(
            'Relatório de Estoque - $dataFormatada',
            style: pw.TextStyle(font: ttfBold, fontSize: 18),
          ),
        ),
        build: (context) => [
          pw.Header(
            level: 1,
            child: pw.Text('Resumo do Dia', style: pw.TextStyle(font: ttfBold)),
          ),

          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: ttfBold, fontSize: 8),
            cellStyle: pw.TextStyle(font: ttf, fontSize: 7),
            headers: [
              'Bebida',
              'Est. Inicial',
              'Vendido',
              'Saída p/ Drinks',
              'Saída p/ Doses',
              'Saída p/ Bar',
              'Observações',
              'Est. Final',
            ],
            data: dadosConsolidados
                .map(
                  (dado) => [
                    dado['nome'],
                    dado['estoqueInicial'].toString(),
                    dado['vendido'].toString(),
                    dado['saidaDrinks'].toString(),
                    dado['saidaDoses'].toString(),
                    dado['saidaOutroBar'].toString(),
                    dado['observacao'],
                    dado['estoqueFinal'].toString(),
                  ],
                )
                .toList(),
            cellAlignments: {
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              7: pw.Alignment.center,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(3),
            },
            border: pw.TableBorder.all(),
          ),

          pw.SizedBox(height: 30),
          pw.Header(
            level: 1,
            child: pw.Text(
              'Registro Detalhado de Movimentações do Dia',
              style: pw.TextStyle(font: ttfBold),
            ),
          ),
          movimentacoesDoDia.isEmpty
              ? pw.Text(
                  'Nenhuma movimentação registrada para esta data.',
                  style: pw.TextStyle(font: ttf),
                )
              : pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(font: ttfBold, fontSize: 8),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 7),
                  headers: ['Bebida', 'Tipo', 'Quantidade', 'Observação'],
                  data: movimentacoesDoDia.map((m) {
                    final qtd = m['quantidade_alterada'] as int;
                    final qtdFormatada = qtd > 0 ? '+$qtd' : qtd.toString();
                    return [
                      m['nome'],
                      m['tipo'],
                      qtdFormatada,
                      m['observacao'] ?? '-',
                    ];
                  }).toList(),
                  cellAlignments: {2: pw.Alignment.center},
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(3),
                  },
                  border: pw.TableBorder.all(),
                ),
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
              _dataSelecionada == null
                  ? 'Selecione uma data...'
                  : DateFormat(
                      'EEEE, dd/MM/yyyy',
                      'pt_BR',
                    ).format(_dataSelecionada!),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selecionarData(context),
            tooltip: 'Selecionar Data',
          ),
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
      body: _dataSelecionada == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Aguardando seleção da data...'),
                ],
              ),
            )
          : FutureBuilder<List<Bebida>>(
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
                      SaidaEstoqueTab(
                        estoque: estoque,
                        onRegistrarSaida: _registrarSaida,
                        onRemover: _mostrarDialogoConfirmarRemocao,
                      ),
                      RelatorioTab(
                        estoque: estoque,
                        onRemover: _mostrarDialogoConfirmarRemocao,
                        onGerarPDF: _gerarRelatorioPDF,
                      ),
                    ],
                  );
                } else if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Erro ao carregar dados: ${snapshot.error}'),
                  );
                }
                return const Center(
                  child: Text(
                    'Nenhuma bebida encontrada. Adicione uma no botão +',
                  ),
                );
              },
            ),
      floatingActionButton: _indiceAbaAtual == 0
          ? FloatingActionButton(
              onPressed: _mostrarDialogoAdicionarBebida,
              backgroundColor: Colors.indigo,
              tooltip: 'Adicionar nova bebida ao catálogo',
              child: const Icon(Icons.add_shopping_cart),
            )
          : null,
    );
  }
}
