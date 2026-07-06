import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  PdfService._();

  static Future<void> gerarRelatorio({
    required DateTime data,
    required List<Map<String, dynamic>> dadosConsolidados,
    required List<Map<String, dynamic>> movimentacoesDoDia,
  }) async {
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(boldFontData);

    final dataFormatada = DateFormat('dd/MM/yyyy', 'pt_BR').format(data);
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
}
