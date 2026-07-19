import 'package:flutter/material.dart';
import 'package:viero_stock/helpers/database_helper.dart';
import 'package:viero_stock/models/bebidas.dart';
import 'package:viero_stock/widgets/operacao_estoque_tab.dart';

class RelatorioTab extends StatefulWidget {
  final DateTime dataSelecionada;
  final Function(Bebida) onRemover;
  final VoidCallback onGerarPDF;

  const RelatorioTab({
    super.key,
    required this.dataSelecionada,
    required this.onRemover,
    required this.onGerarPDF,
  });

  @override
  State<RelatorioTab> createState() => _RelatorioTabState();
}

class _RelatorioTabState extends State<RelatorioTab> {
  late Future<List<Map<String, dynamic>>> _dadosFuture;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void didUpdateWidget(RelatorioTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataSelecionada != widget.dataSelecionada) {
      _carregarDados();
    }
  }

  void _carregarDados() {
    setState(() {
      _dadosFuture = DatabaseHelper.instance.getDadosRelatorioConsolidado(
        widget.dataSelecionada,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _dadosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar dados:\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFF87171)),
            ),
          );
        }

        final dados = snapshot.data ?? [];

        final resumo = dados
            .where(
              (d) =>
                  (d['vendido'] as int) > 0 ||
                  (d['retiradoDoEstoque'] as int) > 0,
            )
            .toList();

        final totalVendido = resumo.fold<int>(
          0,
          (s, d) => s + (d['vendido'] as int),
        );
        final totalSaidas = resumo.fold<int>(
          0,
          (s, d) => s + (d['retiradoDoEstoque'] as int),
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
              child: Row(
                children: [
                  _MetricCard(
                    label: 'Vendas no dia',
                    valor: totalVendido,
                    cor: const Color(0xFFF87171),
                  ),
                  const SizedBox(width: 8),
                  _MetricCard(
                    label: 'Saídas no dia',
                    valor: totalSaidas,
                    cor: const Color(0xFFFB923C),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'RESUMO DO DIA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: Color(0xFF9880C0),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onGerarPDF,
                    icon: const Icon(Icons.picture_as_pdf, size: 14),
                    label: const Text('PDF', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB39DDB),
                      side: const BorderSide(
                        color: Color(0xFF5B35A8),
                        width: 0.5,
                      ),
                      backgroundColor: const Color(0xFF1E1030),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: resumo.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma venda ou saída registrada neste dia.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6B5F80)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: resumo.length,
                      itemBuilder: (ctx, i) => _RelatorioCard(dado: resumo[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int valor;
  final Color cor;

  const _MetricCard({
    required this.label,
    required this.valor,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A2040), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B5F80)),
            ),
            const SizedBox(height: 4),
            Text(
              valor.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: cor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelatorioCard extends StatelessWidget {
  final Map<String, dynamic> dado;

  const _RelatorioCard({required this.dado});

  @override
  Widget build(BuildContext context) {
    final vendido = dado['vendido'] as int;
    final saidas = dado['retiradoDoEstoque'] as int;
    final estoque = dado['estoqueFinal'] as int;
    final estoqueBaixo = estoque < kLimiteEstoqueBaixo;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2040), width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dado['nome'] as String,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFFDDD0F5),
              ),
            ),
          ),
          if (vendido > 0) ...[
            _Stat(
              label: 'Vendas',
              valor: vendido,
              cor: const Color(0xFFF87171),
            ),
            const SizedBox(width: 16),
          ],
          if (saidas > 0) ...[
            _Stat(label: 'Saídas', valor: saidas, cor: const Color(0xFFFB923C)),
            const SizedBox(width: 16),
          ],
          _Stat(
            label: 'Estoque',
            valor: estoque,
            cor: estoqueBaixo
                ? const Color(0xFFF87171)
                : const Color(0xFF6EE7B7),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int valor;
  final Color cor;

  const _Stat({required this.label, required this.valor, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valor.toString(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: cor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B5F80)),
        ),
      ],
    );
  }
}
