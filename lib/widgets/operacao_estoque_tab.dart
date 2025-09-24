import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bebidas.dart';

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
                  onPressed: () {
                    final quantidade = int.tryParse(qtdController.text) ?? 0;
                    final observacao = obsController.text.trim().isEmpty ? null : obsController.text.trim();
                    if (quantidade > 0) {
                      acao(bebida, quantidade, observacao, isAjusteInicial);
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: Text(textoBotao),
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