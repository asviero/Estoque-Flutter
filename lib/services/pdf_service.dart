import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:viero_stock/widgets/operacao_estoque_tab.dart';

class PdfService {
  PdfService._();

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
    final todasAsSaidas = movimentacoesDoDia
        .where((m) => (m['quantidade_alterada'] as int) < 0)
        .toList();

    final Map<String, Map<String, dynamic>> mapaConsumo = {};

    for (var c in consumoStaff) {
      final categoria = c['categoria'] as String? ?? '';
      final item = c['item'] as String? ?? '';
      final quantidade = c['quantidade'] as int? ?? 0;
      final observacao = (c['observacao'] as String?)?.trim() ?? '';

      final key = '$categoria|$item';

      if (mapaConsumo.containsKey(key)) {
        mapaConsumo[key]!['quantidade'] =
            (mapaConsumo[key]!['quantidade'] as int) + quantidade;

        String obsAtual = mapaConsumo[key]!['observacao'] as String;
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

    final consumoStaffAgrupado = mapaConsumo.values.toList();

    consumoStaffAgrupado.sort((a, b) {
      int comp = (a['categoria'] as String).compareTo(b['categoria'] as String);
      if (comp == 0) {
        return (a['item'] as String).compareTo(b['item'] as String);
      }
      return comp;
    });

    final pageFormat = PdfPageFormat.a4.landscape.copyWith(
      marginTop: 20,
      marginBottom: 20,
      marginLeft: 24,
      marginRight: 24,
    );

    final headerStyle = pw.TextStyle(font: ttfBold, fontSize: 8);
    final cellStyle = pw.TextStyle(font: ttf, fontSize: 8);
    const cellCenter = pw.Alignment.center;

    final pdf = pw.Document();

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
              headers: ['Qtd.', 'Bebida', 'Tipo', 'Motivo', 'Observação'],
              data: todasAsSaidas.map((m) {
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
                  m['tipo'],
                  motivo,
                  obs,
                ];
              }).toList(),
              cellAlignments: {0: cellCenter},
              columnWidths: {
                0: const pw.FlexColumnWidth(0.7),
                1: const pw.FlexColumnWidth(2.3),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FlexColumnWidth(2.2),
                4: const pw.FlexColumnWidth(3.0),
              },
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
          ],

          if (consumoStaffAgrupado.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Consumo da Equipe',
              style: pw.TextStyle(font: ttfBold, fontSize: 11),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: headerStyle,
              cellStyle: cellStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
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
              columnWidths: {
                0: const pw.FlexColumnWidth(0.7),
                1: const pw.FlexColumnWidth(3.0),
                2: const pw.FlexColumnWidth(2.0),
                3: const pw.FlexColumnWidth(4.3),
              },
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
