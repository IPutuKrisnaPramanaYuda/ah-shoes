import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/file_download_helper.dart';

class SlipGajiData {
  final String idStaff;
  final String namaStaff;
  final String noTelp;
  final double gajiPokok;
  final double tunjangan;
  final double bpjstk;
  final double thr;
  final double keterlambatan;
  final double cashbon;

  SlipGajiData({
    required this.idStaff,
    required this.namaStaff,
    required this.noTelp,
    required this.gajiPokok,
    this.tunjangan = 0,
    this.bpjstk = 0,
    this.thr = 0,
    this.keterlambatan = 0,
    this.cashbon = 0,
  });

  double get totalPenerimaan => gajiPokok + tunjangan + bpjstk + thr;
  double get totalPotongan => keterlambatan + cashbon;
  double get gajiBersih => totalPenerimaan - totalPotongan;

  String get formattedPhone {
    String clean = noTelp.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      return '62${clean.substring(1)}';
    } else if (clean.startsWith('8')) {
      return '62$clean';
    }
    return clean;
  }
}

class SlipGajiPdfService {
  static final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  static String _formatRupiah(double amount) {
    return 'Rp  ${_currencyFormat.format(amount.round())}';
  }

  /// Generate byte PDF Slip Gaji dengan ukuran khusus voucher/landscape (Bukan A4 besar)
  static Future<Uint8List> generateSlipPdf(SlipGajiData data) async {
    final pdf = pw.Document();

    // Load Logo AH
    pw.MemoryImage? logoImage;
    try {
      final ByteData byteData = await rootBundle.load('assets/logo_ah.png');
      logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (_) {
      // Logo opsional jika gagal load
    }

    // Ukuran slip voucher landscape ringkas (600 x 380 pt) persis seperti template gambar
    const slipFormat = PdfPageFormat(600, 380, marginAll: 10);
    const grayBg = PdfColor.fromInt(0xFFE2E2E2);

    pdf.addPage(
      pw.Page(
        pageFormat: slipFormat,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.black, width: 1.5),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.max,
              children: [
                // 1. HEADER (Logo + Judul + Kontak)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 90,
                        height: 48,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      )
                    else
                      pw.Container(
                        width: 90,
                        height: 48,
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text('AH!',
                            style: pw.TextStyle(
                                color: PdfColors.red900,
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                fontStyle: pw.FontStyle.italic)),
                      ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'SLIP GAJI KARYAWAN AH! SHOES CARE',
                            style: pw.TextStyle(
                              fontSize: 13.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text(
                                '081910695002',
                                style: const pw.TextStyle(fontSize: 8.5),
                              ),
                              pw.SizedBox(width: 14),
                              pw.Text(
                                'Jalan Udayana 10A Singaraja, Bali',
                                style: const pw.TextStyle(fontSize: 8.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 6),
                pw.Container(height: 1.2, color: PdfColors.black),
                pw.SizedBox(height: 5),

                // 2. INFO KARYAWAN (ID & NAMA)
                pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 55,
                      child: pw.Text('ID', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Text(':', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(width: 8),
                    pw.Container(
                      width: 130,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      color: grayBg,
                      child: pw.Text(
                        data.idStaff.isNotEmpty ? data.idStaff.toUpperCase() : '-',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 55,
                      child: pw.Text('NAMA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Text(':', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(width: 8),
                    pw.Container(
                      width: 130,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      color: grayBg,
                      child: pw.Text(
                        data.namaStaff.toUpperCase(),
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 5),
                pw.Container(height: 1.2, color: PdfColors.black),

                // 3. TABEL PENERIMAAN & POTONGAN
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text('PENERIMAAN',
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text('POTONGAN',
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                pw.Container(height: 1, color: PdfColors.black),
                pw.SizedBox(height: 4),

                // BARIS RINCIAN (PENERIMAAN & POTONGAN)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Kolom Penerimaan
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          _buildPdfItemRow('Gaji Pokok', _formatRupiah(data.gajiPokok), grayBg),
                          _buildPdfItemRow('Tunjangan', _formatRupiah(data.tunjangan), grayBg),
                          _buildPdfItemRow('BPJSTK', _formatRupiah(data.bpjstk), grayBg),
                          _buildPdfItemRow('THR', _formatRupiah(data.thr), grayBg),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    // Kolom Potongan
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          _buildPdfItemRow('Keterlambatan', _formatRupiah(data.keterlambatan), grayBg),
                          _buildPdfItemRow('Cashbon', _formatRupiah(data.cashbon), grayBg),
                          _buildPdfItemRow('', '', PdfColors.white),
                          _buildPdfItemRow('', '', PdfColors.white),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 4),
                pw.Container(height: 1, color: PdfColors.black),

                // TOTAL ROW
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL PENERIMAAN',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text(_formatRupiah(data.totalPenerimaan),
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL POTONGAN',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text(_formatRupiah(data.totalPotongan),
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Container(height: 1, color: PdfColors.black),
                pw.SizedBox(height: 8),

                // 4. GAJI BERSIH & TANDA TANGAN
                pw.Row(
                  children: [
                    pw.Text('GAJI BERSIH',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(width: 40),
                    pw.Column(
                      children: [
                        pw.Container(
                          width: 140,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          color: grayBg,
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            _formatRupiah(data.gajiBersih),
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.SizedBox(height: 1),
                        // Double underline persis seperti gambar
                        pw.Container(width: 140, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 1),
                        pw.Container(width: 140, height: 1, color: PdfColors.black),
                      ],
                    ),
                  ],
                ),

                pw.Spacer(),

                // Tanda Tangan
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Payroll', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.SizedBox(height: 28),
                        pw.Text('ALIT HARDY',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Diterima Oleh,', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.SizedBox(height: 28),
                        pw.Text(data.namaStaff.toUpperCase(),
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildPdfItemRow(String label, String value, PdfColor bg) {
    if (label.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.2),
        child: pw.Row(
          children: [
            pw.SizedBox(width: 80),
            pw.Text(''),
          ],
        ),
      );
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
          ),
          pw.Text(':', style: const pw.TextStyle(fontSize: 8.5)),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.8),
              color: bg,
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                value,
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Download Slip Gaji sebagai PDF
  static Future<void> downloadSlip(SlipGajiData data) async {
    final bytes = await generateSlipPdf(data);
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final fileName = 'Slip_Gaji_${data.namaStaff.replaceAll(' ', '_')}_$y$m$d.pdf';
    downloadFile(bytes, fileName, mimeType: 'application/pdf');
  }

  /// Buka Tampilan Cetak (Print Preview) Slip Gaji
  static Future<void> printSlip(SlipGajiData data) async {
    final bytes = await generateSlipPdf(data);
    printPdf(bytes);
  }

  /// Kirim Slip Gaji via WhatsApp & Otomatis Download / Share PDF
  static Future<bool> sendSlipViaWhatsApp(SlipGajiData data, {String? pdfDriveUrl}) async {
    final bytes = await generateSlipPdf(data);
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final fileName = 'Slip_Gaji_${data.namaStaff.replaceAll(' ', '_')}_$y$m$d.pdf';

    // 1. Format tanggal Indonesia tanpa dependensi locale eksternal
    const monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dateStr = '${now.day} ${monthNames[now.month - 1]} ${now.year}';

    final linkSection = (pdfDriveUrl != null && pdfDriveUrl.isNotEmpty)
        ? '\n📄 *DOKUMEN RESMI SLIP GAJI (PDF):*\nBuka / Unduh Slip Gaji di sini:\n👉 $pdfDriveUrl\n'
        : '';

    // 2. Format pesan WA yang lengkap dan profesional
    final message = '''
*SLIP GAJI KARYAWAN AH! SHOES CARE*
Tanggal: $dateStr

Halo *${data.namaStaff}* (${data.idStaff.isNotEmpty ? data.idStaff : '-'}),
Berikut rincian slip gaji Anda:

*PENERIMAAN:*
• Gaji Pokok: ${_formatRupiah(data.gajiPokok)}
• Tunjangan: ${_formatRupiah(data.tunjangan)}
• BPJSTK: ${_formatRupiah(data.bpjstk)}
• THR: ${_formatRupiah(data.thr)}
*Total Penerimaan:* ${_formatRupiah(data.totalPenerimaan)}

*POTONGAN:*
• Keterlambatan: ${_formatRupiah(data.keterlambatan)}
• Cashbon: ${_formatRupiah(data.cashbon)}
*Total Potongan:* ${_formatRupiah(data.totalPotongan)}

=========================
*GAJI BERSIH: ${_formatRupiah(data.gajiBersih)}*
=========================
$linkSection
_Dokumen PDF slip gaji resmi terlampir. Terima kasih atas dedikasi dan kerja keras Anda di AH! Shoes Care._
''';

    // 3. Coba share file PDF langsung (Web Share) atau buka WA + download PDF
    return await shareFileOrOpenWhatsApp(bytes, fileName, data.formattedPhone, message);
  }
}
