import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:viero_stock/widgets/operacao_estoque_tab.dart';

class PdfService {
  PdfService._();

  static pw.Widget _buildTable({
    required List<String> headers,
    required List<List<Object?>> data,
    required List<double> widths,
    required pw.TextStyle headerStyle,
    required pw.TextStyle cellStyle,
    Map<int, pw.Alignment>? cellAlignments,
  }) {
    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
      columnWidths: {
        for (int i = 0; i < widths.length; i++)
          i: pw.FlexColumnWidth(widths[i]),
      },
      cellAlignments: cellAlignments ?? {},
    );
  }

  static Future<void> gerarRelatorio({
    required DateTime data,
    required List<Map<String, dynamic>> dadosConsolidados,
    required List<Map<String, dynamic>> movimentacoesDoDia,
    required List<Map<String, dynamic>> consumoStaff,
  }) async {
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(boldFontData);

    final dataFormatada = DateFormat('dd/MM/yyyy', 'pt_BR').format(data);
    final detalhes = movimentacoesDoDia.where((m) {
      final tipo = m['tipo'] as String;
      final obs = (m['observacao'] as String? ?? '').trim();
      if ((m['quantidade_alterada'] as int) >= 0) return false;
      if (tipo == 'Saída para Bar') return true;
      if (tipo == 'Venda') return obs.isNotEmpty;
      return false;
    }).toList();

    final entradas = movimentacoesDoDia.where((m) {
      final tipo = m['tipo'] as String;
      final obs = (m['observacao'] as String? ?? '').trim();
      return tipo == 'Entrada' && obs.isNotEmpty;
    }).toList();

    final Map<String, Map<String, dynamic>> mapaConsumo = {};

    for (var c in consumoStaff) {
      final categoria = c['categoria'] as String? ?? '';
      final item = c['item'] as String? ?? '';
      final quantidade = c['quantidade'] as int? ?? 0;
      final observacao = (c['observacao'] as String?)?.trim() ?? '';

      final key = '$categoria|$item|$observacao';

      if (mapaConsumo.containsKey(key)) {
        mapaConsumo[key]!['quantidade'] =
            (mapaConsumo[key]!['quantidade'] as int) + quantidade;

        final String obsAtual = mapaConsumo[key]!['observacao'] as String;
        if (observacao.isNotEmpty && observacao != '-') {
          if (obsAtual == '-' || obsAtual.isEmpty) {
            mapaConsumo[key]!['observacao'] = observacao;
          } else if (!obsAtual.contains(observacao)) {
            mapaConsumo[key]!['observacao'] = '$obsAtual, $observacao';
          }
        }
      } else {
        mapaConsumo[key] = {
          'categoria': categoria,
          'item': item,
          'quantidade': quantidade,
          'observacao': observacao.isEmpty ? '-' : observacao,
        };
      }
    }

    final consumoStaffAgrupado = mapaConsumo.values.toList()
      ..sort((a, b) {
        final comp = (a['categoria'] as String).compareTo(
          b['categoria'] as String,
        );
        return comp != 0
            ? comp
            : (a['item'] as String).compareTo(b['item'] as String);
      });

    final pageFormat = PdfPageFormat.a4.copyWith(
      marginTop: 8,
      marginBottom: 8,
      marginLeft: 8,
      marginRight: 8,
    );

    final headerStyle = pw.TextStyle(font: ttfBold, fontSize: 7.5);
    final cellStyle = pw.TextStyle(font: ttf, fontSize: 7.5);
    const cellCenter = pw.Alignment.center;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Relatório de Estoque — $dataFormatada',
                style: pw.TextStyle(font: ttfBold, fontSize: 13),
              ),
              pw.Text(
                'Gerado em ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now())}',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 7.5,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Text(
            'Resumo do dia:',
            style: pw.TextStyle(
              font: ttfBold,
              fontSize: 10,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 4),
          _buildTable(
            headerStyle: headerStyle,
            cellStyle: cellStyle,
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
            widths: [4, 1, 1, 1, 1, 1],
          ),

          if (entradas.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Resumo das entradas do estoque:',
              style: pw.TextStyle(
                font: ttfBold,
                fontSize: 10,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.SizedBox(height: 4),
            _buildTable(
              headerStyle: headerStyle,
              cellStyle: cellStyle,
              headers: ['Qtd.', 'Bebida', 'Observação'],
              data: entradas
                  .map(
                    (m) => [
                      (m['quantidade_alterada'] as int).toString(),
                      m['nome'],
                      (m['observacao'] as String? ?? '-'),
                    ],
                  )
                  .toList(),
              cellAlignments: {0: cellCenter},
              widths: [1, 3, 6],
            ),
          ],

          if (detalhes.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Resumo das saídas do estoque:',
              style: pw.TextStyle(
                font: ttfBold,
                fontSize: 10,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.SizedBox(height: 4),
            _buildTable(
              headerStyle: headerStyle,
              cellStyle: cellStyle,
              headers: ['Qtd.', 'Bebida', 'Motivo da Saída', 'Observação'],
              data: detalhes.map((m) {
                final raw = m['observacao'] as String? ?? '';
                final sepIdx = raw.indexOf(' — ');
                final String motivo;
                final String obs;
                if (sepIdx != -1 &&
                    kMotivosSaida.contains(raw.substring(0, sepIdx))) {
                  motivo = raw.substring(0, sepIdx);
                  obs = raw.substring(sepIdx + 3);
                } else if (kMotivosSaida.contains(raw)) {
                  motivo = raw;
                  obs = '-';
                } else {
                  motivo = '-';
                  obs = raw.isEmpty ? '-' : raw;
                }
                return [
                  (m['quantidade_alterada'] as int).abs().toString(),
                  m['nome'],
                  motivo,
                  obs,
                ];
              }).toList(),
              cellAlignments: {0: cellCenter},
              widths: [1, 3, 3, 5],
            ),
          ],

          if (consumoStaffAgrupado.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Consumo da equipe:',
              style: pw.TextStyle(
                font: ttfBold,
                fontSize: 10,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.SizedBox(height: 4),
            _buildTable(
              headerStyle: headerStyle,
              cellStyle: cellStyle,
              headers: ['Qtd.', 'Item', 'Categoria', 'Observação'],
              data: consumoStaffAgrupado
                  .map(
                    (c) => [
                      (c['quantidade'] as int).toString(),
                      c['item'],
                      c['categoria'],
                      c['observacao'] ?? '-',
                    ],
                  )
                  .toList(),
              cellAlignments: {0: cellCenter},
              widths: [1, 3, 2, 4],
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
