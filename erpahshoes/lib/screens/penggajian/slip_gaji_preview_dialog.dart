import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/slip_gaji_pdf_service.dart';
import '../../utils/app_theme.dart';

class SlipGajiPreviewDialog extends StatefulWidget {
  final SlipGajiData slipData;
  final VoidCallback? onBayarGaji;

  const SlipGajiPreviewDialog({
    Key? key,
    required this.slipData,
    this.onBayarGaji,
  }) : super(key: key);

  @override
  State<SlipGajiPreviewDialog> createState() => _SlipGajiPreviewDialogState();
}

class _SlipGajiPreviewDialogState extends State<SlipGajiPreviewDialog> {
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');
  bool _isProcessing = false;

  String _formatRp(double val) {
    return 'Rp ${_currencyFormat.format(val.round())}';
  }

  SlipGajiData _getCurrentData() {
    return widget.slipData;
  }

  Future<void> _handleDownload() async {
    setState(() => _isProcessing = true);
    try {
      await SlipGajiPdfService.downloadSlip(_getCurrentData());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slip Gaji (PDF) berhasil diunduh ke komputer!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh slip: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handlePrint() async {
    setState(() => _isProcessing = true);
    try {
      await SlipGajiPdfService.printSlip(_getCurrentData());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Membuka pratinjau cetak slip gaji...'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak slip: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _getCurrentData();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Cetak Slip Gaji - ${data.namaStaff}',
                        style: GoogleFonts.openSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Modal Body: Slip Preview + Phone Input
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Tampilan Fisik Slip Gaji (Persis Foto Template)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 1.6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Header Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/logo_ah.png',
                                width: 90,
                                height: 48,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Text(
                                  'AH!',
                                  style: GoogleFonts.openSans(
                                    color: Colors.red.shade900,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'SLIP GAJI KARYAWAN AH! SHOES CARE',
                                      style: GoogleFonts.openSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.phone, size: 12, color: Color(0xFFD81B60)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '081910695002',
                                          style: GoogleFonts.openSans(fontSize: 10, color: Colors.black),
                                        ),
                                        const SizedBox(width: 14),
                                        const Icon(Icons.location_on, size: 12, color: Color(0xFFD81B60)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Jalan Udayana 10A Singaraja, Bali',
                                          style: GoogleFonts.openSans(fontSize: 10, color: Colors.black),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          const Divider(height: 1, thickness: 1.4, color: Colors.black),
                          const SizedBox(height: 6),

                          // 2. Info Karyawan
                          Row(
                            children: [
                              SizedBox(
                                width: 60,
                                child: Text('ID', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                              ),
                              Text(':', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                              const SizedBox(width: 8),
                              Container(
                                width: 140,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                color: const Color(0xFFDCDCDC),
                                child: Text(
                                  data.idStaff.isNotEmpty ? data.idStaff.toUpperCase() : '-',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              SizedBox(
                                width: 60,
                                child: Text('NAMA', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                              ),
                              Text(':', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                              const SizedBox(width: 8),
                              Container(
                                width: 140,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                color: const Color(0xFFDCDCDC),
                                child: Text(
                                  data.namaStaff.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),
                          const Divider(height: 1, thickness: 1.4, color: Colors.black),

                          // 3. Header Penerimaan & Potongan
                          Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text('PENERIMAAN', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text('POTONGAN', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 1, thickness: 1, color: Colors.black),
                          const SizedBox(height: 6),

                          // Rincian Baris Penerimaan & Potongan
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Kiri: Penerimaan
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildPreviewItemRow('Gaji Pokok', _formatRp(data.gajiPokok)),
                                    _buildPreviewItemRow('Tunjangan', _formatRp(data.tunjangan)),
                                    _buildPreviewItemRow('BPJSTK', _formatRp(data.bpjstk)),
                                    _buildPreviewItemRow('THR', _formatRp(data.thr)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Kanan: Potongan
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildPreviewItemRow('Keterlambatan', _formatRp(data.keterlambatan)),
                                    _buildPreviewItemRow('Cashbon', _formatRp(data.cashbon)),
                                    _buildPreviewItemRow('', ''),
                                    _buildPreviewItemRow('', ''),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),
                          const Divider(height: 1, thickness: 1, color: Colors.black),

                          // Total Baris
                          Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('TOTAL PENERIMAAN', style: GoogleFonts.openSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black)),
                                      Text(_formatRp(data.totalPenerimaan), style: GoogleFonts.openSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('TOTAL POTONGAN', style: GoogleFonts.openSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black)),
                                      Text(_formatRp(data.totalPotongan), style: GoogleFonts.openSans(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 1, thickness: 1, color: Colors.black),
                          const SizedBox(height: 10),

                          // 4. GAJI BERSIH
                          Row(
                            children: [
                              Text('GAJI BERSIH', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                              const SizedBox(width: 40),
                              Column(
                                children: [
                                  Container(
                                    width: 150,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    color: const Color(0xFFDCDCDC),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _formatRp(data.gajiBersih),
                                      style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(width: 150, height: 1, color: Colors.black),
                                  const SizedBox(height: 1),
                                  Container(width: 150, height: 1, color: Colors.black),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Tanda Tangan
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Payroll', style: GoogleFonts.openSans(fontSize: 10, color: Colors.black)),
                                  const SizedBox(height: 35),
                                  Text('ALIT HARDY', style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Diterima Oleh,', style: GoogleFonts.openSans(fontSize: 10, color: Colors.black)),
                                  const SizedBox(height: 35),
                                  Text(data.namaStaff.toUpperCase(), style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer: Action Buttons (Download, Kirim WA, Tandai Bayar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (widget.onBayarGaji != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                      label: Text('Tandai Sudah Dibayar', style: GoogleFonts.openSans(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      onPressed: _isProcessing ? null : widget.onBayarGaji,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tombol Download Slip Gaji PDF
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download, size: 17, color: Colors.white),
                        label: Text('Download PDF', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                        onPressed: _isProcessing ? null : _handleDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Tombol Cetak Slip Gaji (Print Preview Browser)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print, size: 17, color: Colors.white),
                        label: Text('Cetak PDF', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                        onPressed: _isProcessing ? null : _handlePrint,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewItemRow(String label, String value) {
    if (label.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 3),
        child: SizedBox(height: 18),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(label, style: GoogleFonts.openSans(fontSize: 10, color: Colors.black)),
          ),
          Text(':', style: GoogleFonts.openSans(fontSize: 10, color: Colors.black)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: const Color(0xFFDCDCDC),
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
