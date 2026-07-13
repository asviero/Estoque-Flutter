import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viero_stock/models/bebidas.dart';

const int kLimiteEstoqueBaixo = 3;

const List<String> kMotivosSaida = [
  'Reposição do Bar Grande',
  'Aniversário',
  'Drinks',
  'Doses',
  'Quebra / Perda',
  'Outros',
];

class OperacaoEstoqueTab extends StatelessWidget {
  final List<Bebida> estoque;
  final String titulo;
  final Function(Bebida, int, String?, bool) acao;
  final Function(Bebida) onRemover;
  final Color corBotao;
  final Color corBotaoTexto;
  final Color corBotaoBorda;
  final String textoBotao;

  const OperacaoEstoqueTab({
    super.key,
    required this.estoque,
    required this.titulo,
    required this.acao,
    required this.onRemover,
    required this.corBotao,
    required this.corBotaoTexto,
    required this.corBotaoBorda,
    required this.textoBotao,
  });

  void _mostrarDialogoDeQuantidade(BuildContext context, Bebida bebida) {
    final qtdController = TextEditingController();
    final obsController = TextEditingController();
    bool isAjusteInicial = false;
    String? motivoSelecionado;
    final isEntrada = titulo == 'Entrada no Estoque';
    final isSaida = titulo == 'Saídas';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              '$textoBotao — ${bebida.nome}',
              style: const TextStyle(fontSize: 16),
            ),
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
                  if (isSaida) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: motivoSelecionado,
                      decoration: const InputDecoration(labelText: 'Motivo'),
                      items: kMotivosSaida
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => motivoSelecionado = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: obsController,
                    decoration: const InputDecoration(
                      labelText: 'Observação (opcional)',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  if (isEntrada)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: CheckboxListTile(
                        title: const Text(
                          'Definir como estoque inicial',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: isAjusteInicial,
                        onChanged: (v) =>
                            setDialogState(() => isAjusteInicial = v ?? false),
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
                onPressed: () {
                  final quantidade = int.tryParse(qtdController.text) ?? 0;
                  if (quantidade > 0) {
                    final obsTexto = obsController.text.trim();
                    final String? obs;
                    if (motivoSelecionado != null && obsTexto.isNotEmpty) {
                      obs = '$motivoSelecionado — $obsTexto';
                    } else if (motivoSelecionado != null) {
                      obs = motivoSelecionado;
                    } else if (obsTexto.isNotEmpty) {
                      obs = obsTexto;
                    } else {
                      obs = null;
                    }
                    acao(bebida, quantidade, obs, isAjusteInicial);
                  }
                  Navigator.of(ctx).pop();
                },
                child: Text(textoBotao),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Color(0xFF9880C0),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: PageStorageKey<String>('scroll_estoque_$titulo'),
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: estoque.length,
            itemBuilder: (ctx, index) {
              final bebida = estoque[index];
              final estoqueBaixo = bebida.quantidade < kLimiteEstoqueBaixo;
              return _BebidaCard(
                bebida: bebida,
                estoqueBaixo: estoqueBaixo,
                textoBotao: textoBotao,
                corBotao: corBotao,
                corBotaoTexto: corBotaoTexto,
                corBotaoBorda: corBotaoBorda,
                onAcao: () => _mostrarDialogoDeQuantidade(ctx, bebida),
                onRemover: () => onRemover(bebida),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BebidaCard extends StatelessWidget {
  final Bebida bebida;
  final bool estoqueBaixo;
  final String textoBotao;
  final Color corBotao;
  final Color corBotaoTexto;
  final Color corBotaoBorda;
  final VoidCallback onAcao;
  final VoidCallback onRemover;

  const _BebidaCard({
    required this.bebida,
    required this.estoqueBaixo,
    required this.textoBotao,
    required this.corBotao,
    required this.corBotaoTexto,
    required this.corBotaoBorda,
    required this.onAcao,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: estoqueBaixo
              ? const Color(0xFFB03060)
              : const Color(0xFF2A2040),
          width: estoqueBaixo ? 1.5 : 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          bebida.nome,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFDDD0F5),
          ),
        ),
        subtitle: Text(
          'Estoque: ${bebida.quantidade} un.',
          style: TextStyle(
            fontSize: 12,
            color: estoqueBaixo
                ? const Color(0xFFF87171)
                : const Color(0xFF6B5F80),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onAcao,
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: corBotao,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: corBotaoBorda, width: 0.5),
                ),
                child: Text(
                  textoBotao,
                  style: TextStyle(fontSize: 12, color: corBotaoTexto),
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: onRemover,
              borderRadius: BorderRadius.circular(7),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1020),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF4A1535),
                    width: 0.5,
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Color(0xFF9B3A5A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
