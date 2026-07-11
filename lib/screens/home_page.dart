import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:viero_stock/helpers/database_helper.dart';
import 'package:viero_stock/models/bebidas.dart';
import 'package:viero_stock/services/pdf_service.dart';
import 'package:viero_stock/widgets/operacao_estoque_tab.dart';
import 'package:viero_stock/widgets/relatorio_tab.dart';
import 'package:viero_stock/widgets/staff_tab.dart';

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
    _tabController = TabController(length: 5, vsync: this);
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
      setState(() {
        _dataSelecionada = dataEscolhida;
        _listaBebidas = dbHelper.getEstoqueParaData(_dataSelecionada);
      });
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
    final dadosConsolidados = await dbHelper.getDadosRelatorioConsolidado(
      _dataSelecionada,
    );
    final movimentacoesDoDia = await dbHelper.getMovimentacoesDoDia(
      _dataSelecionada,
    );
    final consumoStaff = await dbHelper.getConsumoStaffDoDia(_dataSelecionada);

    await PdfService.gerarRelatorio(
      data: _dataSelecionada,
      dadosConsolidados: dadosConsolidados,
      movimentacoesDoDia: movimentacoesDoDia,
      consumoStaff: consumoStaff,
    );
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
            Tab(icon: Icon(Icons.people, size: 18), text: 'Staff'),
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
              StaffTab(dataSelecionada: _dataSelecionada),
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
