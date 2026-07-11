import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viero_stock/helpers/database_helper.dart';

const List<String> kCategoriasStaff = [
  'Adriano',
  'Fábio',
  'Rodolfo',
  'DJ',
  'Camarim',
  'Banda',
  'Equipe Moon',
];

class StaffTab extends StatefulWidget {
  final DateTime dataSelecionada;

  const StaffTab({super.key, required this.dataSelecionada});

  @override
  State<StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<StaffTab> {
  late Future<List<Map<String, dynamic>>> _consumoFuture;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void didUpdateWidget(StaffTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataSelecionada != widget.dataSelecionada) {
      _carregarDados();
    }
  }

  void _carregarDados() {
    setState(() {
      _consumoFuture = DatabaseHelper.instance.getConsumoStaffDoDia(
        widget.dataSelecionada,
      );
    });
  }

  void _mostrarDialogoAdicionar() {
    final itemController = TextEditingController();
    final qtdController = TextEditingController();
    final obsController = TextEditingController();
    String? categoriaSelecionada;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Registrar Consumo',
              style: TextStyle(fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: categoriaSelecionada,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: kCategoriasStaff
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => categoriaSelecionada = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: itemController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Item'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtdController,
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: obsController,
                    decoration: const InputDecoration(
                      labelText: 'Observação (opcional)',
                    ),
                    textCapitalization: TextCapitalization.sentences,
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
                onPressed: () async {
                  final categoria = categoriaSelecionada;
                  final item = itemController.text.trim();
                  final quantidade = int.tryParse(qtdController.text) ?? 0;
                  if (categoria != null && item.isNotEmpty && quantidade > 0) {
                    await DatabaseHelper.instance.insertConsumoStaff(
                      data: widget.dataSelecionada,
                      categoria: categoria,
                      item: item,
                      quantidade: quantidade,
                      observacao: obsController.text.trim().isEmpty
                          ? null
                          : obsController.text.trim(),
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    _carregarDados();
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deletarConsumo(int id) async {
    await DatabaseHelper.instance.deleteConsumoStaff(id);
    _carregarDados();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _consumoFuture,
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

        final consumo = snapshot.data ?? [];
        final total = consumo.fold<int>(
          0,
          (s, c) => s + (c['quantidade'] as int),
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CONSUMO DA EQUIPE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: Color(0xFF9880C0),
                          ),
                        ),
                        if (total > 0)
                          Text(
                            '$total itens registrados',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B5F80),
                            ),
                          ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _mostrarDialogoAdicionar,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text(
                      'Registrar',
                      style: TextStyle(fontSize: 12),
                    ),
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
              child: consumo.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum consumo registrado neste dia.\nToque em Registrar para adicionar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6B5F80)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: consumo.length,
                      itemBuilder: (ctx, i) {
                        final item = consumo[i];
                        return _ConsumoCard(
                          item: item,
                          onDeletar: () => _deletarConsumo(item['id'] as int),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ConsumoCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDeletar;

  const _ConsumoCard({required this.item, required this.onDeletar});

  static const _corCategoria = {
    'Adriano': Color(0xFF7C3AED),
    'Fábio': Color(0xFF8B5CF6),
    'Rodolfo': Color(0xFF10B981),
    'DJ': Color(0xFFF59E0B),
    'Camarim': Color(0xFF0EA5E9),
    'Banda': Color(0xFF6B5F80),
    'Equipe Moon': Color.fromARGB(255, 12, 0, 185),
  };

  @override
  Widget build(BuildContext context) {
    final categoria = item['categoria'] as String;
    final cor = _corCategoria[categoria] ?? const Color(0xFF6B5F80);
    final obs = item['observacao'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2040), width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: cor.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        categoria,
                        style: TextStyle(
                          fontSize: 10,
                          color: cor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['item'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFDDD0F5),
                        ),
                      ),
                    ),
                    Text(
                      '${item['quantidade']} un.',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6EE7B7),
                      ),
                    ),
                  ],
                ),
                if (obs != null && obs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    obs,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7A6F8A),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onDeletar,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1020),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF4A1535), width: 0.5),
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
    );
  }
}
