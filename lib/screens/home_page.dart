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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
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
    setState(() => _indiceAbaAtual = _tabController.index);
  }

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

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );
    if (dataEscolhida != null && dataEscolhida != _dataSelecionada) {
      setState(() => _dataSelecionada = dataEscolhida);
      await Future.delayed(const Duration(milliseconds: 100));
      _refreshBebidasList();
    }
  }

  Future<void> _adicionarEstoque(
    Bebida bebida,
    int quantidade,
    String? observacao,
    bool isAjusteInicial,
  ) async {
    final tipo = isAjusteInicial ? 'Ajuste Inicial' : 'Entrada';
    await dbHelper.adicionarMovimentacao(
      bebidaId: bebida.id,
      data: _dataSelecionada,
      quantidade: quantidade,
      tipo: tipo,
      observacao: observacao,
    );
    _refreshBebidasList();
    _mostrarSnackBar(
      '$quantidade un. de ${bebida.nome} adicionadas.',
      Colors.green.shade700,
    );
  }

  Future<void> _registrarMovimentacaoNegativa(
    Bebida bebida,
    int quantidade,
    String? observacao,
    String tipo,
    String mensagemSucesso,
    Color corSucesso,
  ) async {
    final estoqueAtual = await dbHelper.getEstoqueAtualDaBebida(
      bebida.id,
      _dataSelecionada,
    );
    if (estoqueAtual >= quantidade) {
      await dbHelper.adicionarMovimentacao(
        bebidaId: bebida.id,
        data: _dataSelecionada,
        quantidade: -quantidade,
        tipo: tipo,
        observacao: observacao,
      );
      _refreshBebidasList();
      _mostrarSnackBar(mensagemSucesso, corSucesso);
    } else {
      _mostrarSnackBar(
        'Estoque insuficiente para ${bebida.nome}.',
        Colors.red.shade700,
      );
    }
  }

  Future<void> _registrarSaida(
    Bebida bebida,
    int quantidade,
    String? observacao,
    bool _,
  ) => _registrarMovimentacaoNegativa(
    bebida,
    quantidade,
    observacao,
    'Saída para Bar',
    '$quantidade un. de ${bebida.nome} saíram para o bar.',
    Colors.orange.shade800,
  );

  Future<void> _registrarVenda(
    Bebida bebida,
    int quantidade,
    String? observacao,
    bool _,
  ) => _registrarMovimentacaoNegativa(
    bebida,
    quantidade,
    observacao,
    'Venda',
    '$quantidade un. de ${bebida.nome} foram vendidas.',
    Colors.red.shade700,
  );

  void _mostrarSnackBar(String mensagem, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: cor));
  }

  Future<void> _adicionarNovaBebida(String nome) async {
    if (nome.trim().isEmpty) return;
    final id = nome
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    await dbHelper.insertBebida(Bebida(id: id, nome: nome));
    _refreshBebidasList();
    _mostrarSnackBar(
      '${nome.trim()} adicionado(a) ao catálogo.',
      const Color(0xFF4A1D96),
    );
  }

  Future<void> _removerBebida(String id, String nome) async {
    await dbHelper.deleteBebida(id);
    _refreshBebidasList();
    _mostrarSnackBar('$nome removido(a) do catálogo.', Colors.red.shade900);
  }

  void _mostrarDialogoConfirmarRemocao(Bebida bebida) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text(
          'Deseja remover "${bebida.nome}" do catálogo? Todo o histórico será perdido.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton(
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
        title: const Text('Nova Bebida'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da Bebida'),
          textCapitalization: TextCapitalization.words,
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
    ).format(_dataSelecionada);
    final dadosConsolidados = await dbHelper.getDadosRelatorioConsolidado(
      _dataSelecionada,
    );
    final movimentacoesDoDia = await dbHelper.getMovimentacoesDoDia(
      _dataSelecionada,
    );
    final todasAsSaidas = movimentacoesDoDia
        .where((m) => (m['quantidade_alterada'] as int) < 0)
        .toList();

    final pageFormat = PdfPageFormat.a4.landscape.copyWith(
      marginTop: 20,
      marginBottom: 20,
      marginLeft: 24,
      marginRight: 24,
    );

    final headerStyle = pw.TextStyle(font: ttfBold, fontSize: 8);
    final cellStyle = pw.TextStyle(font: ttf, fontSize: 8);
    final cellCenter = pw.Alignment.center;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Relatório de Estoque — $dataFormatada',
                style: pw.TextStyle(font: ttfBold, fontSize: 14),
              ),
              pw.Text(
                'Gerado em ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now())}',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Text(
            'Resumo do Dia',
            style: pw.TextStyle(font: ttfBold, fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: headerStyle,
            cellStyle: cellStyle,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: [
              'Bebida',
              'Est. Inicial',
              'Entradas',
              'Vendas',
              'Saídas',
              'Est. Final',
            ],
            data: dadosConsolidados
                .map(
                  (d) => [
                    d['nome'],
                    d['estoqueInicial'].toString(),
                    ((d['estoqueFinal'] as int) -
                            (d['estoqueInicial'] as int) +
                            (d['vendido'] as int) +
                            (d['retiradoDoEstoque'] as int))
                        .toString(),
                    d['vendido'].toString(),
                    d['retiradoDoEstoque'].toString(),
                    d['estoqueFinal'].toString(),
                  ],
                )
                .toList(),
            cellAlignments: {
              1: cellCenter,
              2: cellCenter,
              3: cellCenter,
              4: cellCenter,
              5: cellCenter,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(3.5),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.2),
            },
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),

          if (todasAsSaidas.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Detalhes das Saídas',
              style: pw.TextStyle(font: ttfBold, fontSize: 11),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: headerStyle,
              cellStyle: cellStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              headers: ['Qtd.', 'Bebida', 'Tipo', 'Observação'],
              data: todasAsSaidas
                  .map(
                    (m) => [
                      (m['quantidade_alterada'] as int).abs().toString(),
                      m['nome'],
                      m['tipo'],
                      m['observacao'] ?? '-',
                    ],
                  )
                  .toList(),
              cellAlignments: {0: cellCenter},
              columnWidths: {
                0: const pw.FlexColumnWidth(0.8),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(4.7),
              },
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
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
            const Text(
              'ESTOQUE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: Color(0xFFE8D5FF),
              ),
            ),
            Text(
              DateFormat('EEEE, dd/MM/yyyy', 'pt_BR').format(_dataSelecionada),
              style: const TextStyle(fontSize: 12, color: Color(0xFF7A6F8A)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () => _selecionarData(context),
              icon: const Icon(Icons.calendar_today, size: 14),
              label: const Text('Data', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB39DDB),
                side: const BorderSide(color: Color(0xFF3D2F6E)),
                backgroundColor: const Color(0xFF1A1A2E),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          tabs: const [
            Tab(icon: Icon(Icons.add_shopping_cart, size: 18), text: 'Entrada'),
            Tab(icon: Icon(Icons.point_of_sale, size: 18), text: 'Vendas'),
            Tab(icon: Icon(Icons.local_bar, size: 18), text: 'Saída'),
            Tab(icon: Icon(Icons.assessment, size: 18), text: 'Relatório'),
          ],
        ),
      ),
      body: FutureBuilder<List<Bebida>>(
        future: _listaBebidas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma bebida encontrada.\nAdicione uma com o botão +',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B5F80)),
              ),
            );
          }

          final estoque = snapshot.data!;
          return TabBarView(
            controller: _tabController,
            children: [
              OperacaoEstoqueTab(
                estoque: estoque,
                titulo: 'Entrada no Estoque',
                acao: _adicionarEstoque,
                onRemover: _mostrarDialogoConfirmarRemocao,
                corBotao: const Color(0xFF2D1B5E),
                corBotaoTexto: const Color(0xFFC4A8FF),
                corBotaoBorda: const Color(0xFF5B35A8),
                textoBotao: 'Adicionar',
              ),
              OperacaoEstoqueTab(
                estoque: estoque,
                titulo: 'Registrar Venda',
                acao: _registrarVenda,
                onRemover: _mostrarDialogoConfirmarRemocao,
                corBotao: const Color(0xFF3B0A1A),
                corBotaoTexto: const Color(0xFFFCA5A5),
                corBotaoBorda: const Color(0xFF9B1D3A),
                textoBotao: 'Vender',
              ),
              OperacaoEstoqueTab(
                estoque: estoque,
                titulo: 'Saídas',
                acao: _registrarSaida,
                onRemover: _mostrarDialogoConfirmarRemocao,
                corBotao: const Color(0xFF2D1800),
                corBotaoTexto: const Color(0xFFFBD38D),
                corBotaoBorda: const Color(0xFF92400E),
                textoBotao: 'Enviar',
              ),
              RelatorioTab(
                dataSelecionada: _dataSelecionada,
                onRemover: _mostrarDialogoConfirmarRemocao,
                onGerarPDF: _gerarRelatorioPDF,
              ),
            ],
          );
        },
      ),
      floatingActionButton: _indiceAbaAtual == 0
          ? FloatingActionButton(
              onPressed: _mostrarDialogoAdicionarBebida,
              tooltip: 'Nova bebida',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
