// lib/widgets/saida_estoque_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bebidas.dart';

// Widget especializado para a aba de Saída, com diálogo de seleção de motivo.
class SaidaEstoqueTab extends StatelessWidget {
  final List<Bebida> estoque;
  final Function(Bebida, int, String?, String)
  onRegistrarSaida; // Ação específica de saída
  final Function(Bebida) onRemover;

  const SaidaEstoqueTab({
    super.key,
    required this.estoque,
    required this.onRegistrarSaida,
    required this.onRemover,
  });

  void _mostrarDialogoDeSaida(BuildContext context, Bebida bebida) {
    final qtdController = TextEditingController();
    final obsController = TextEditingController();
    String motivoSelecionado = 'Saída - Drinks'; // Valor inicial padrão

    showDialog(
      context: context,
      builder: (ctx) {
        // StatefulBuilder permite atualizar o estado apenas dentro do diálogo
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Saída de ${bebida.nome}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Motivo da Saída:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    // Botões de Rádio para selecionar o motivo
                    RadioListTile<String>(
                      title: const Text('Drinks'),
                      value: 'Saída - Drinks',
                      groupValue: motivoSelecionado,
                      onChanged: (value) =>
                          setDialogState(() => motivoSelecionado = value!),
                    ),
                    RadioListTile<String>(
                      title: const Text('Doses'),
                      value: 'Saída - Doses',
                      groupValue: motivoSelecionado,
                      onChanged: (value) =>
                          setDialogState(() => motivoSelecionado = value!),
                    ),
                    RadioListTile<String>(
                      title: const Text('Transferência p/ outro Bar'),
                      value: 'Saída - Outro Bar',
                      groupValue: motivoSelecionado,
                      onChanged: (value) =>
                          setDialogState(() => motivoSelecionado = value!),
                    ),
                    const Divider(),
                    TextField(
                      controller: qtdController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: obsController,
                      decoration: const InputDecoration(
                        labelText: 'Observação (Opcional)',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final quantidade = int.tryParse(qtdController.text) ?? 0;
                    final observacao = obsController.text.trim().isEmpty
                        ? null
                        : obsController.text.trim();
                    if (quantidade > 0) {
                      onRegistrarSaida(
                        bebida,
                        quantidade,
                        observacao,
                        motivoSelecionado,
                      );
                    }
                    Navigator.of(ctx).pop();
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Enviar'),
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
              'Saída para os Bares',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: estoque.length,
              itemBuilder: (ctx, index) {
                final bebida = estoque[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      bebida.nome,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Estoque atual: ${bebida.quantidade}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () =>
                              _mostrarDialogoDeSaida(context, bebida),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('Enviar'),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_forever,
                            color: Colors.red.shade400,
                          ),
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
