import 'package:flutter/material.dart';

import '../models/bebidas.dart';

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
                      padding: const EdgeInsets.symmetric(horizontal: 16)),
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
                              color: bebida.quantidade < 10 ? Colors.red.shade400 : Colors.green.shade400),
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