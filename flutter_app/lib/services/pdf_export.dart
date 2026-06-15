import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/aspirasi_model.dart';
import 'package:intl/intl.dart';

class PdfExport {
  static Future<void> generateAndPrint(List<Aspirasi> items) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SWAAP - Laporan Aspirasi & Aduan',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Tanggal Cetak: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 16),
            ],
          );
        },
        build: (context) {
          return [
            pw.TableHelper.fromTextArray(
              headers: ['No', 'Tanggal', 'Pengirim', 'Sasaran', 'Kritik & Saran', 'Status', 'Catatan Admin'],
              cellAlignment: pw.Alignment.topLeft,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              columnWidths: {
                0: const pw.FixedColumnWidth(25),
                1: const pw.FixedColumnWidth(55),
                2: const pw.FixedColumnWidth(70),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FlexColumnWidth(),
                5: const pw.FixedColumnWidth(50),
                6: const pw.FixedColumnWidth(70),
              },
              data: List<List<String>>.generate(items.length, (i) {
                final a = items[i];
                final dateStr = DateFormat('dd/MM/yyyy\nHH:mm').format(a.createdAt);
                final pengirim = a.isAnonim ? 'Anonim\n${a.semester}\n${a.jurusan}' : '${a.nama}\n${a.nim}';
                final kritikSaran = 'Kritik:\n${a.kritik}\n\nSaran:\n${a.saran}';
                return [
                  '${i + 1}',
                  dateStr,
                  pengirim,
                  a.sasaran,
                  kritikSaran,
                  a.status.toUpperCase(),
                  a.adminReply,
                ];
              }),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Aspirasi_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
