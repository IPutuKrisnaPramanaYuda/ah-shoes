import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/kasir_service.dart';
import '../../services/bluetooth_printer_service.dart';
import '../../services/printer_models.dart';
import '../../utils/app_theme.dart';
import '../../utils/whatsapp_helper.dart';
import 'printer_settings_dialog.dart';

class RiwayatScreen extends StatefulWidget {
  final String? initialFilter;

  const RiwayatScreen({Key? key, this.initialFilter}) : super(key: key);

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  final KasirService _kasirService = KasirService();
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  List<Map<String, dynamic>> _transaksiList = [];
  bool _isLoading = true;
  String _selectedFilter = 'Semua';
  final List<String> _filters = ['Semua', 'Dikerjakan', 'Selesai', 'Diambil'];

  Future<void> _printReceiptForTrx(Map<String, dynamic> trx) async {
    final itemsRaw = (trx['items'] as List?) ?? [];
    final totalHarga = double.tryParse(trx['total_harga']?.toString() ?? '0') ?? 0;
    
    final receiptData = ReceiptData(
      idTransaksi: trx['id_transaksi']?.toString() ?? '',
      kodeUnik: (trx['kode_unik'] ?? '').toString().isNotEmpty ? trx['kode_unik'].toString() : '-',
      tanggal: trx['tanggal']?.toString().split('T')[0] ?? '',
      waktu: trx['waktu']?.toString() ?? '',
      namaPelanggan: trx['nama_pelanggan']?.toString() ?? '',
      noHp: trx['no_hp']?.toString() ?? '',
      namaKasir: trx['nama_kasir']?.toString() ?? '',
      metodeBayar: trx['metode_bayar']?.toString() ?? '',
      statusBayar: trx['status_bayar']?.toString() ?? '',
      totalHarga: totalHarga.toInt(),
      totalItem: itemsRaw.isNotEmpty ? itemsRaw.length : (int.tryParse(trx['total_item']?.toString() ?? '1') ?? 1),
      items: itemsRaw.map((it) => ReceiptItemData(
        namaTreatment: it['nama_treatment']?.toString() ?? '-',
        harga: double.tryParse(it['harga_treatment']?.toString() ?? '0')?.toInt() ?? 0,
        jenisItem: it['jenis_item']?.toString() ?? '',
        merek: it['merek']?.toString() ?? '',
        warna: it['warna']?.toString() ?? '',
        ukuran: it['ukuran']?.toString() ?? '',
        staffNama: it['nama_staff']?.toString() ?? '',
      )).toList(),
    );

    bool connected = await _printerService.isConnected();
    if (!connected) {
      connected = await _printerService.autoConnect();
    }

    if (!connected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Printer belum terhubung. Silakan hubungkan printer Iware.', style: GoogleFonts.openSans()),
          backgroundColor: AppColors.error,
        ));
        PrinterSettingsDialog.show(context);
      }
      return;
    }

    final printOk = await _printerService.printReceipt(receiptData);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(printOk ? 'Struk berhasil dicetak!' : 'Gagal mencetak struk. Cek printer.',
            style: GoogleFonts.openSans()),
        backgroundColor: printOk ? AppColors.success : AppColors.error,
      ));
    }
  }

  /// Mengirim pesan WhatsApp ke pelanggan bahwa cucian sudah selesai & siap diambil
  Future<void> _kirimWaPelanggan(Map<String, dynamic> trx) async {
    final String hp = (trx['no_hp'] ?? '').toString().trim();
    if (hp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Nomor HP pelanggan tidak ditemukan pada transaksi ini.', style: GoogleFonts.openSans(fontSize: 13)),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final message = WhatsAppHelper.createSelesaiMessage(
      namaPelanggan: (trx['nama_pelanggan'] ?? '').toString(),
      idTransaksi: (trx['id_transaksi'] ?? '').toString(),
      kodeUnik: (trx['kode_unik'] ?? '').toString(),
      items: (trx['items'] as List?) ?? [],
      totalHarga: trx['total_harga'],
      statusBayar: (trx['status_bayar'] ?? '').toString(),
      metodeBayar: (trx['metode_bayar'] ?? '').toString(),
    );

    // Dialog preview sebelum kirim
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF25D366),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kirim Notifikasi WA', style: GoogleFonts.openSans(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('Pelanggan: ${trx['nama_pelanggan']} ($hp)',
                      style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 280),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: Text(
              message,
              style: GoogleFonts.openSans(fontSize: 11.5, height: 1.4),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.openSans(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final success = await WhatsAppHelper.openWhatsApp(
                phoneNumber: hp,
                message: message,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Gagal membuka WhatsApp. Pastikan format nomor benar ($hp).', style: GoogleFonts.openSans()),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.send, color: Colors.white, size: 14),
            label: Text('Kirim Sekarang',
                style: GoogleFonts.openSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null && _filters.contains(widget.initialFilter)) {
      _selectedFilter = widget.initialFilter!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _kasirService.getTransaksi();
    
    // Urutkan terbaru di atas
    setState(() {
      _transaksiList = data.reversed.toList();
      _isLoading = false;
    });
  }

  String _formatIsoDate(dynamic isoString) {
    if (isoString == null || isoString.toString().isEmpty) return '';
    try {
      final str = isoString.toString();
      if (str.contains('T') && str.contains('Z')) {
        final date = DateTime.parse(str).toLocal();
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      return str;
    } catch (e) {
      return isoString.toString();
    }
  }

  List<Map<String, dynamic>> get _filteredList {
    if (_selectedFilter == 'Semua') return _transaksiList;
    return _transaksiList.where((t) => t['status'] == _selectedFilter).toList();
  }

  Color _getStatusColor(String status) {
    if (status == 'Dikerjakan') return Colors.orange;
    if (status == 'Selesai') return AppColors.primary;
    if (status == 'Diambil') return AppColors.success;
    return AppColors.textHint;
  }

  void _showUpdateStatusDialog(Map<String, dynamic> trx) {
    String selectedStatus = trx['status'] ?? 'Dikerjakan';
    final String statusBayar = trx['status_bayar']?.toString() ?? '';
    final bool isBelumLunas = statusBayar == 'Bayar Saat Selesai' || statusBayar == '';
    final double totalHarga = double.tryParse(trx['total_harga']?.toString() ?? '0') ?? 0;
    
    String metodeBayar = 'Cash';
    final TextEditingController uangDiterimaController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bool showPayment = selectedStatus == 'Diambil' && isBelumLunas;
          
          return AlertDialog(
            title: Text('Update Status', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${trx['id_transaksi']}', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Status Pengerjaan',
                      labelStyle: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: ['Dikerjakan', 'Selesai', 'Diambil'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.openSans(fontSize: 14)))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setModalState(() => selectedStatus = v);
                      }
                    },
                  ),
                  
                  if (showPayment) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    Text('PELUNASAN PEMBAYARAN', style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textHint, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    Text('Total: Rp ${totalHarga.toInt()}', style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 10),
                    Row(
                      children: ['Cash', 'QRIS'].map((m) {
                        final sel = metodeBayar == m;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                metodeBayar = m;
                                if (m != 'Cash') uangDiterimaController.clear();
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.only(right: m == 'Cash' ? 8 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.primary : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                              ),
                              alignment: Alignment.center,
                              child: Text(m, style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textSecondary)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    if (metodeBayar == 'Cash') ...[
                      TextFormField(
                        controller: uangDiterimaController,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setModalState((){}),
                        style: GoogleFonts.openSans(fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Nominal Uang (Rp)',
                          labelStyle: GoogleFonts.openSans(fontSize: 11, color: AppColors.textHint),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (uangDiterimaController.text.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Kembalian', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                            Builder(
                              builder: (context) {
                                final uang = double.tryParse(uangDiterimaController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                final kembalian = uang - totalHarga;
                                return Text('Rp ${kembalian < 0 ? 0 : kembalian.toInt()}', 
                                  style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: kembalian >= 0 ? AppColors.success : AppColors.error));
                              }
                            ),
                          ],
                        ),
                    ]
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: GoogleFonts.openSans(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (showPayment && metodeBayar == 'Cash') {
                    final uang = double.tryParse(uangDiterimaController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                    if (uang < totalHarga) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Nominal uang tidak cukup'), backgroundColor: AppColors.error));
                      return;
                    }
                  }
                  
                  Navigator.pop(ctx);
                  
                  if (selectedStatus != trx['status'] || showPayment) {
                    _updateStatusWithPayment(trx['id_transaksi'], selectedStatus, showPayment ? metodeBayar : null);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Simpan', style: GoogleFonts.openSans(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateStatusWithPayment(String idTrx, String newStatus, String? metodeBayar) async {
    setState(() => _isLoading = true);
    final ok = await _kasirService.updateStatusTransaksi(
      idTrx, 
      newStatus, 
      metodeBayar: metodeBayar,
      statusBayar: metodeBayar != null ? 'Lunas' : null,
    );
    if (ok) {
      await _loadData();
      if (mounted) {
        if (newStatus == 'Selesai') {
          // Tampilkan SnackBar dengan tombol langsung kirim WA
          final targetTrx = _transaksiList.firstWhere(
            (t) => t['id_transaksi'] == idTrx,
            orElse: () => <String, dynamic>{},
          );
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Status diupdate: Selesai', style: GoogleFonts.openSans(fontSize: 13)),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
            action: targetTrx.isNotEmpty
                ? SnackBarAction(
                    label: 'KIRIM WA',
                    textColor: Colors.white,
                    onPressed: () => _kirimWaPelanggan(targetTrx),
                  )
                : null,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Status berhasil diupdate', style: GoogleFonts.openSans(fontSize: 13)),
            backgroundColor: AppColors.success,
          ));
        }
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mengupdate status', style: GoogleFonts.openSans(fontSize: 13)),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredList;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarStandard(
        context, 'Riwayat Transaksi',
        actions: [
          IconButton(
            icon: const Icon(Icons.print, size: 20, color: AppColors.primary),
            tooltip: 'Pengaturan Printer Bluetooth',
            onPressed: () => PrinterSettingsDialog.show(context),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // Filter tabs
          Container(
            color: AppColors.surface,
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: _filters.map((f) {
                  final isSelected = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedFilter = f),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(
                          f,
                          style: GoogleFonts.openSans(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(
                        child: Text('Belum ada transaksi', 
                          style: GoogleFonts.openSans(color: AppColors.textHint, fontSize: 14)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final trx = list[index];
                          final status = trx['status'] ?? 'Dikerjakan';
                          final items = (trx['items'] as List?) ?? [];
                          final kodeUnik = (trx['kode_unik'] ?? '').toString();
                          final isSelesai = status == 'Selesai';
                          
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            color: AppColors.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            trx['id_transaksi'] ?? '',
                                            style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                          ),
                                          if (kodeUnik.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryLight,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                              ),
                                              child: Text(
                                                '#$kodeUnik',
                                                style: GoogleFonts.openSans(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      InkWell(
                                        onTap: () => _showUpdateStatusDialog(trx),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                status,
                                                style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusColor(status)),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(Icons.edit, size: 10, color: _getStatusColor(status)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.person, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          trx['nama_pelanggan'] ?? '-',
                                          style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 14, color: AppColors.textHint),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${trx['tanggal'].toString().split('T')[0]} ${trx['waktu']}',
                                        style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                  if ((trx['waktu_selesai'] ?? '').toString().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                                        const SizedBox(width: 8),
                                        Text('Selesai: ${_formatIsoDate(trx['waktu_selesai'])}', style: GoogleFonts.openSans(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ],
                                  if ((trx['waktu_diambil'] ?? '').toString().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.outbox, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Text('Diambil: ${_formatIsoDate(trx['waktu_diambil'])}', style: GoogleFonts.openSans(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ],
                                  const Divider(height: 24, color: AppColors.divider),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${items.length} Item:', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                      if ((trx['status_bayar'] ?? '').toString().isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: trx['status_bayar'] == 'Lunas' || trx['status_bayar'] == 'Bayar Sekarang' ? AppColors.success.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: trx['status_bayar'] == 'Lunas' || trx['status_bayar'] == 'Bayar Sekarang' ? AppColors.success : Colors.red),
                                          ),
                                          child: Text(
                                            trx['status_bayar'] == 'Lunas' || trx['status_bayar'] == 'Bayar Sekarang' ? 'Lunas (${trx['metode_bayar'] ?? '-'})' : 'Belum Lunas',
                                            style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: trx['status_bayar'] == 'Lunas' || trx['status_bayar'] == 'Bayar Sekarang' ? AppColors.success : Colors.red),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...items.map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('• ', style: GoogleFonts.openSans(fontSize: 14, color: AppColors.textHint)),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['nama_treatment'] ?? '-',
                                                style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                              ),
                                              if ((item['nama_staff'] ?? '').toString().isNotEmpty)
                                                Text(
                                                  'Dikerjakan oleh: ${item['nama_staff']}',
                                                  style: GoogleFonts.openSans(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textHint),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Total', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                        Text('Rp ${trx['total_harga']}', style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Tombol Kirim WA — Khusus yang berstatus "Selesai"
                                      if (isSelesai) ...[
                                        ElevatedButton.icon(
                                          onPressed: () => _kirimWaPelanggan(trx),
                                          icon: const Icon(Icons.chat, size: 14, color: Colors.white),
                                          label: Text('Kirim WA',
                                              style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF25D366),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      OutlinedButton.icon(
                                        onPressed: () => _printReceiptForTrx(trx),
                                        icon: const Icon(Icons.print, size: 14),
                                        label: Text('Cetak Struk', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(color: AppColors.primary),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                      ),
                                    ],
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
