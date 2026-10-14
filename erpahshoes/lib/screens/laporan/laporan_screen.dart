import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/opex_model.dart';
import '../../services/kasir_service.dart';
import '../../services/penggajian_service.dart';
import '../../services/opex_service.dart';
import '../../services/inventory_service.dart';
import '../../utils/app_theme.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> with SingleTickerProviderStateMixin {
  final KasirService _kasirService = KasirService();
  final PenggajianService _penggajianService = PenggajianService();
  final OpexService _opexService = OpexService();
  final InventoryService _inventoryService = InventoryService();

  late TabController _tabController;
  bool _isLoading = true;

  // Kas Float
  double _saldoKasAwal = 1000000;
  static const String _keyKasAwal = 'kunci_saldo_kas_awal';

  // Transaksi Penjualan
  final List<Map<String, dynamic>> _uangRealList = [];
  final List<Map<String, dynamic>> _uangPiutangList = [];
  double _totalUangReal = 0;
  double _totalUangPiutang = 0;

  // Penggajian
  List<Map<String, dynamic>> _gajiTerbayarList = [];
  List<Map<String, dynamic>> _gajiBelumDibayarList = [];
  double _totalGajiTerbayar = 0;
  double _totalGajiBelumDibayar = 0;

  // OPEX & CAPEX
  List<OpexItem> _opexList = [];
  List<CapexItem> _capexList = [];
  double _totalBiayaOpex = 0;
  double _totalNilaiAsetCapex = 0;
  double _totalPenyusutanCapexPerBulan = 0;

  // Restok Bahan Baku
  List<Map<String, dynamic>> _logRestockList = [];
  double _totalBiayaRestock = 0;

  // Barang Fisik IN / OUT
  final List<Map<String, dynamic>> _barangIn = [];
  final List<Map<String, dynamic>> _barangOut = [];
  int _totalBarangIn = 0;
  int _totalBarangOut = 0;
  double _totalUangBarangIn = 0;
  double _totalUangBarangOut = 0;

  // Filter Sub-Tab Pengeluaran
  String _selectedPengeluaranFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    // 1. Muat Saldo Kas Awal dari SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _saldoKasAwal = prefs.getDouble(_keyKasAwal) ?? 1000000;

    // 2. Fetch data paralel dari Google Sheets
    try {
      final results = await Future.wait([
        _kasirService.getTransaksi(),
        _penggajianService.getPenggajian(forceRefresh: true),
        _penggajianService.getLogPenggajian(forceRefresh: true),
        _opexService.getOpex(),
        _opexService.getCapex(),
        _inventoryService.getLogRestock(),
      ]);

      final transaksiData = results[0] as List<Map<String, dynamic>>;
      final penggajianData = results[1] as List<Map<String, dynamic>>;
      final logPenggajianData = results[2] as List<Map<String, dynamic>>;
      final rawOpexData = results[3] as List<OpexItem>;
      final capexData = results[4] as List<CapexItem>;
      final logRestockData = results[5] as List<Map<String, dynamic>>;

      _processData(
        transaksi: transaksiData,
        penggajian: penggajianData,
        logPenggajian: logPenggajianData,
        rawOpex: rawOpexData,
        capex: capexData,
        logRestock: logRestockData,
      );
    } catch (e) {
      debugPrint("Error loading financial data: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _processData({
    required List<Map<String, dynamic>> transaksi,
    required List<Map<String, dynamic>> penggajian,
    required List<Map<String, dynamic>> logPenggajian,
    required List<OpexItem> rawOpex,
    required List<CapexItem> capex,
    required List<Map<String, dynamic>> logRestock,
  }) {
    _logRestockList = logRestock;

    // A. Transaksi & Barang
    _barangIn.clear();
    _barangOut.clear();
    _totalBarangIn = 0;
    _totalBarangOut = 0;
    _totalUangBarangIn = 0;
    _totalUangBarangOut = 0;

    _uangRealList.clear();
    _uangPiutangList.clear();
    _totalUangReal = 0;
    _totalUangPiutang = 0;

    for (var trx in transaksi) {
      final status = (trx['status'] ?? '').toString();
      final statusBayar = (trx['status_bayar'] ?? '').toString();
      final totalHarga = double.tryParse(trx['total_harga'].toString()) ?? 0;
      final items = (trx['items'] as List?) ?? [];

      // Keuangan: Real vs Piutang
      if (statusBayar == 'Bayar Sekarang' || statusBayar == 'Lunas' || status == 'Diambil') {
        _uangRealList.add(trx);
        _totalUangReal += totalHarga;
      } else {
        _uangPiutangList.add(trx);
        _totalUangPiutang += totalHarga;
      }

      // Barang: Masuk vs Keluar
      for (var item in items) {
        final itemData = {
          'id_transaksi': trx['id_transaksi'],
          'nama_pelanggan': trx['nama_pelanggan'],
          'tanggal': trx['tanggal'],
          'status_trx': status,
          ...Map<String, dynamic>.from(item)
        };
        final hargaItem = double.tryParse(item['harga_treatment'].toString()) ?? 0;

        if (status == 'Diambil') {
          _barangOut.add(itemData);
          _totalBarangOut += 1;
          _totalUangBarangOut += hargaItem;
        } else {
          _barangIn.add(itemData);
          _totalBarangIn += 1;
          _totalUangBarangIn += hargaItem;
        }
      }
    }

    // B. GAJI SUDAH DIBAYARKAN (Arus Kas Keluar Real - Terpotong Otomatis)
    final validLogs = logPenggajian.where((l) {
      final id = (l['id_log'] ?? '').toString().trim();
      final nama = (l['nama_staff'] ?? '').toString().trim();
      return id.isNotEmpty && id != 'ID_Gaji' && nama != 'NAMA_STAFF';
    }).toList();
    _gajiTerbayarList = validLogs;
    _totalGajiTerbayar = 0;
    for (var log in validLogs) {
      final bayar = double.tryParse(log['total_bayar']?.toString() ?? '0') ?? 0;
      _totalGajiTerbayar += bayar;
    }

    // C. GAJI BELUM DIBAYARKAN (Kewajiban Penggajian Berjalan)
    final validPending = penggajian.where((p) {
      final nama = (p['nama_staff'] ?? '').toString().trim();
      return nama.isNotEmpty && nama != 'NAMA_STAFF';
    }).toList();
    _gajiBelumDibayarList = validPending;
    _totalGajiBelumDibayar = 0;
    for (var p in validPending) {
      final gaji = double.tryParse(p['total_gaji']?.toString() ?? '0') ?? 0;
      _totalGajiBelumDibayar += gaji;
    }

    // D. OPEX Harian (Rutin sehari-hari saja, filter out barang yang merupakan penyusutan/aset mesin)
    _opexList = rawOpex.where((o) {
      final kat = o.kategori.toLowerCase();
      return kat != 'penyusutan' && !o.namaPengeluaran.toLowerCase().contains('mesin');
    }).toList();

    _totalBiayaOpex = 0;
    for (var o in _opexList) {
      _totalBiayaOpex += o.totalBiaya;
    }

    // E. CAPEX (Aset Modal & Penyusutan)
    _capexList = capex;
    _totalNilaiAsetCapex = 0;
    _totalPenyusutanCapexPerBulan = 0;
    for (var c in capex) {
      _totalNilaiAsetCapex += (c.hargaBarang * c.quantity);
      _totalPenyusutanCapexPerBulan += c.biayaPerBulan;
    }

    // F. Restok Bahan Baku
    _totalBiayaRestock = 0;
    for (var r in logRestock) {
      final b = double.tryParse(r['total_biaya']?.toString() ?? '0') ?? 0;
      _totalBiayaRestock += b;
    }
  }

  // --- Perhitungan Saldo Kas Riil & Proyeksi ---
  double get _saldoKasSaatIni {
    // SALDO KAS RIIL = Kas Awal + Penjualan Real - Gaji Terbayar - OPEX Harian - Restok Bahan
    return _saldoKasAwal + _totalUangReal - _totalGajiTerbayar - _totalBiayaOpex - _totalBiayaRestock;
  }

  double get _proyeksiPendapatan {
    return _totalUangReal + _totalUangPiutang;
  }

  double get _proyeksiTotalBeban {
    // Beban mencakup: Total Gaji (Terbayar + Belum Bayar) + OPEX Rutin + Restok Bahan Baku + Penyisihan CAPEX
    return (_totalGajiTerbayar + _totalGajiBelumDibayar) + _totalBiayaOpex + _totalBiayaRestock + _totalPenyusutanCapexPerBulan;
  }

  double get _proyeksiLabaBersih {
    return _proyeksiPendapatan - _proyeksiTotalBeban;
  }

  double get _profitMarginPercent {
    if (_proyeksiPendapatan <= 0) return 0;
    return (_proyeksiLabaBersih / _proyeksiPendapatan) * 100;
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(amount);
  }

  // --- Dialog Set Saldo Kas Awal ---
  Future<void> _showSetKasAwalDialog() async {
    final controller = TextEditingController(text: _saldoKasAwal.toInt().toString());
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Atur Kas Awal', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan modal uang kas kasir/laci. Saldo kas saat ini akan dihitung otomatis: Kas Awal + Penjualan Real - Gaji Terbayar - OPEX - Restok.',
                style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nominal Kas Awal (Rp)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: GoogleFonts.openSans(color: AppColors.textHint)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final input = double.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble(_keyKasAwal, input);
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                setState(() => _saldoKasAwal = input);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kas awal berhasil diatur ke ${_formatCurrency(input)}'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: Text('Simpan', style: GoogleFonts.openSans(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- Modal Lembar Audit Rincian Pemotongan Kas ---
  void _showAuditPemotonganKasModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle Bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit Kalkulasi Saldo Kas',
                        style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      Text(
                        'Rincian detail pemotongan uang kas operasional',
                        style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Box Ringkasan Rumus
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildFormulaRow('1. Modal Kas Awal', _formatCurrency(_saldoKasAwal), Colors.blue.shade700, isBold: true),
                        const SizedBox(height: 6),
                        _buildFormulaRow('2. (+) Penjualan Real (Kas Masuk)', '+${_formatCurrency(_totalUangReal)}', AppColors.success),
                        const SizedBox(height: 6),
                        _buildFormulaRow('3. (-) Gaji Terbayar (Log Pencairan)', '-${_formatCurrency(_totalGajiTerbayar)}', Colors.orange.shade800),
                        const SizedBox(height: 6),
                        _buildFormulaRow('4. (-) OPEX Harian (Belanja Konsumsi dll)', '-${_formatCurrency(_totalBiayaOpex)}', Colors.purple.shade800),
                        const SizedBox(height: 6),
                        _buildFormulaRow('5. (-) Restok Bahan Baku', '-${_formatCurrency(_totalBiayaRestock)}', Colors.amber.shade900),
                        const Divider(height: 16),
                        _buildFormulaRow('SALDO KAS SAAT INI', _formatCurrency(_saldoKasSaatIni), _saldoKasSaatIni >= 0 ? Colors.blue.shade900 : Colors.red, isBold: true, fontSize: 15),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bagian 1: Rincian Gaji Terbayar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                          const SizedBox(width: 6),
                          Text('Gaji Karyawan Terbayar (${_gajiTerbayarList.length})', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Text('-${_formatCurrency(_totalGajiTerbayar)}', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_gajiTerbayarList.isEmpty)
                    Text('Belum ada riwayat gaji terbayar.', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint))
                  else
                    ..._gajiTerbayarList.map((log) => _buildMiniAuditRow(
                          icon: Icons.person,
                          title: log['nama_staff'] ?? '-',
                          subtitle: '${log['tanggal']} • ${log['id_log']}',
                          amount: -(double.tryParse(log['total_bayar']?.toString() ?? '0') ?? 0),
                          badge: 'Terpotong dari Kas',
                          badgeColor: Colors.green,
                        )),

                  const SizedBox(height: 16),

                  // Bagian 2: OPEX Harian
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, color: Colors.purple, size: 18),
                          const SizedBox(width: 6),
                          Text('Pengeluaran OPEX Harian (${_opexList.length})', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Text('-${_formatCurrency(_totalBiayaOpex)}', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_opexList.isEmpty)
                    Text('Belum ada data pengeluaran OPEX harian.', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint))
                  else
                    ..._opexList.map((o) => _buildMiniAuditRow(
                          icon: Icons.local_grocery_store_outlined,
                          title: o.namaPengeluaran,
                          subtitle: '${o.kategori} • ${o.tanggalMasuk}',
                          amount: -o.totalBiaya,
                          badge: 'OPEX Kas',
                          badgeColor: Colors.purple,
                        )),

                  const SizedBox(height: 16),

                  // Bagian 3: Restok Bahan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Text('Restok Bahan Baku (${_logRestockList.length})', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Text('-${_formatCurrency(_totalBiayaRestock)}', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_logRestockList.isEmpty)
                    Text('Belum ada riwayat restok bahan.', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textHint))
                  else
                    ..._logRestockList.map((r) => _buildMiniAuditRow(
                          icon: Icons.layers_outlined,
                          title: r['nama_item'] ?? '-',
                          subtitle: '${r['qty_masuk']} qty • ${r['tanggal']}',
                          amount: -(double.tryParse(r['total_biaya']?.toString() ?? '0') ?? 0),
                          badge: 'Restok Kas',
                          badgeColor: Colors.amber,
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulaRow(String label, String value, Color color, {bool isBold = false, double fontSize = 12}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.openSans(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: const Color(0xFF334155))),
        Text(value, style: GoogleFonts.openSans(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildMiniAuditRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required double amount,
    required String badge,
    required MaterialColor badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: badgeColor.shade50,
            child: Icon(icon, size: 14, color: badgeColor.shade700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(subtitle, style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatCurrency(amount), style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: badgeColor.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(badge, style: GoogleFonts.openSans(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor.shade800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Laporan Keuangan & Operasional',
              style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            Text(
              'Monitoring Arus Kas, Gaji, CAPEX & OPEX',
              style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Atur Kas Awal',
            icon: const Icon(Icons.settings_suggest_rounded, color: AppColors.primary),
            onPressed: _showSetKasAwalDialog,
          ),
          IconButton(
            tooltip: 'Perbarui Data',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Dashboard'),
            Tab(icon: Icon(Icons.attach_money_rounded, size: 18), text: 'Penjualan'),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Pengeluaran'),
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'Barang'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Memuat data keuangan terpadu...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabDashboard(),
                _buildTabPenjualan(),
                _buildTabPengeluaran(),
                _buildTabBarang(),
              ],
            ),
    );
  }

  // ==========================================
  // TAB 1: EXECUTIVE FINANCIAL DASHBOARD
  // ==========================================
  Widget _buildTabDashboard() {
    final saldoKas = _saldoKasSaatIni;
    final isKasPositive = saldoKas >= 0;

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. CARD SALDO KAS UTAMA
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isKasPositive
                    ? [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]
                    : [const Color(0xFF991B1B), const Color(0xFFEF4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isKasPositive ? Colors.blue : Colors.red).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'SALDO KAS OPERASIONAL (REAL-TIME)',
                          style: GoogleFonts.openSans(
                            color: Colors.white70,
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: _showAuditPemotonganKasModal,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.receipt_long, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text('Audit Potongan', style: GoogleFonts.openSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _showSetKasAwalDialog,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text('Kas Awal', style: GoogleFonts.openSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _formatCurrency(saldoKas),
                  style: GoogleFonts.openSans(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kas Awal: ${_formatCurrency(_saldoKasAwal)}  •  Penjualan Real: +${_formatCurrency(_totalUangReal)}',
                  style: GoogleFonts.openSans(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                ),
                const Divider(color: Colors.white24, height: 24),
                // Breakdown Chips Pemotongan Kas Otomatis
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCashChip(
                      icon: Icons.payments_rounded,
                      label: 'Gaji Terbayar (Potong Kas)',
                      amount: -_totalGajiTerbayar,
                      color: Colors.orange.shade100,
                      textColor: Colors.orange.shade900,
                    ),
                    _buildCashChip(
                      icon: Icons.local_grocery_store_rounded,
                      label: 'OPEX Harian',
                      amount: -_totalBiayaOpex,
                      color: Colors.purple.shade100,
                      textColor: Colors.purple.shade900,
                    ),
                    _buildCashChip(
                      icon: Icons.inventory_rounded,
                      label: 'Restok Bahan',
                      amount: -_totalBiayaRestock,
                      color: Colors.amber.shade100,
                      textColor: Colors.amber.shade900,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. KARTU BEBAN GAJI KARYAWAN (TERBAYAR VS BELUM DIBAYAR)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.people_alt_rounded, color: Colors.orange, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status Gaji Karyawan',
                              style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Gaji Terbayar (Potong Kas) vs Belum Dibayar',
                              style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        setState(() => _selectedPengeluaranFilter = 'Gaji Terbayar');
                        _tabController.animateTo(2);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Lihat Detail',
                          style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Box Gaji Sudah Terbayar
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('SUDAH DIBAYAR', style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(4)),
                                  child: Text('POTONG KAS', style: GoogleFonts.openSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(_formatCurrency(_totalGajiTerbayar), style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF15803D))),
                            const SizedBox(height: 2),
                            Text('${_gajiTerbayarList.length} Transaksi Pencairan', style: GoogleFonts.openSans(fontSize: 10, color: const Color(0xFF166534))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Box Gaji Belum Dibayar
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('BELUM DIBAYAR', style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF92400E))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(4)),
                                  child: Text('KEWAJIBAN', style: GoogleFonts.openSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(_formatCurrency(_totalGajiBelumDibayar), style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
                            const SizedBox(height: 2),
                            Text('${_gajiBelumDibayarList.length} Staf Menunggu Cair', style: GoogleFonts.openSans(fontSize: 10, color: const Color(0xFF92400E))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '💡 Gaji yang sudah dicairkan otomatis memotong saldo kas. Gaji yang belum dibayar belum memotong kas sampai dicairkan di menu Penggajian.',
                  style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. CARD ALOKASI PENYISIHAN CAPEX (DANA CADANGAN PENYUSUTAN)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.precision_manufacturing_rounded, color: Colors.indigo, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Penyisihan Biaya CAPEX',
                              style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Dana Cadangan Penyusutan Aset & Mesin',
                              style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_capexList.length} Aset',
                        style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        title: 'Wajib Disisihkan / Bln',
                        value: _formatCurrency(_totalPenyusutanCapexPerBulan),
                        valueColor: Colors.indigo,
                        subtitle: 'Penyusutan dari ${_formatCurrency(_totalNilaiAsetCapex)} aset',
                      ),
                    ),
                    Container(width: 1, height: 40, color: AppColors.border),
                    Expanded(
                      child: _buildMetricTile(
                        title: 'Beban Harian (26 hr)',
                        value: _formatCurrency(_totalPenyusutanCapexPerBulan / 26),
                        valueColor: AppColors.textPrimary,
                        subtitle: 'Beban amortisasi harian',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sisihkan ${_formatCurrency(_totalPenyusutanCapexPerBulan)} tiap bulan dari laba ke rekening cadangan untuk perbaikan/penggantian mesin tanpa mengganggu kas operasional.',
                          style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. CARD PROYEKSI KEUANGAN BULAN INI
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.trending_up_rounded, color: Colors.teal, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Proyeksi Keuangan Bulan Ini',
                              style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Estimasi Laba Bersih & Profit Margin',
                              style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildHealthBadge(_profitMarginPercent),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        title: 'Proyeksi Omzet',
                        value: _formatCurrency(_proyeksiPendapatan),
                        valueColor: AppColors.success,
                        subtitle: 'Real: ${_formatCurrency(_totalUangReal)} | Piutang: ${_formatCurrency(_totalUangPiutang)}',
                      ),
                    ),
                    Container(width: 1, height: 40, color: AppColors.border),
                    Expanded(
                      child: _buildMetricTile(
                        title: 'Total Beban Bulan Ini',
                        value: _formatCurrency(_proyeksiTotalBeban),
                        valueColor: Colors.red.shade700,
                        subtitle: 'Semua Gaji, OPEX, Restok & Aset',
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PROYEKSI LABA BERSIH', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        Text(
                          _formatCurrency(_proyeksiLabaBersih),
                          style: GoogleFonts.openSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _proyeksiLabaBersih >= 0 ? AppColors.success : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('PROFIT MARGIN', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        Text(
                          '${_profitMarginPercent.toStringAsFixed(1)}%',
                          style: GoogleFonts.openSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _profitMarginPercent >= 20 ? AppColors.success : (_profitMarginPercent >= 0 ? Colors.orange : Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 5. RINGKASAN ARUS KAS MASUK VS KELUAR
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rincian Beban Terhadap Kas',
                      style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    InkWell(
                      onTap: _showAuditPemotonganKasModal,
                      child: Text('Detail Audit >', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCashflowRow('Uang Masuk dari Penjualan Real', _totalUangReal, isPositive: true),
                const Divider(height: 16),
                _buildCashflowRow('Gaji Karyawan Terbayar (Otomatis Terpotong)', _totalGajiTerbayar, isPositive: false),
                _buildCashflowRow('OPEX Harian (Galon, Jajan, Tisu, dll)', _totalBiayaOpex, isPositive: false),
                _buildCashflowRow('Pembelian / Restok Bahan Baku', _totalBiayaRestock, isPositive: false),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Uang Kas Berkurang', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text(
                      '-${_formatCurrency(_totalGajiTerbayar + _totalBiayaOpex + _totalBiayaRestock)}',
                      style: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCashChip({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            '$label: ${_formatCurrency(amount.abs())}',
            style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required Color valueColor,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
        const SizedBox(height: 2),
        Text(subtitle, style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildHealthBadge(double margin) {
    Color bg = Colors.green.shade50;
    Color text = Colors.green.shade800;
    String label = 'Sehat';

    if (margin >= 30) {
      bg = Colors.green.shade100;
      text = Colors.green.shade900;
      label = 'Sangat Sehat';
    } else if (margin >= 10) {
      bg = Colors.blue.shade50;
      text = Colors.blue.shade800;
      label = 'Stabil';
    } else if (margin >= 0) {
      bg = Colors.orange.shade50;
      text = Colors.orange.shade800;
      label = 'Margin Tipis';
    } else {
      bg = Colors.red.shade50;
      text = Colors.red.shade800;
      label = 'Defisit';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
    );
  }

  Widget _buildCashflowRow(String label, double amount, {required bool isPositive}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
          Text(
            '${isPositive ? '+' : '-'}${_formatCurrency(amount)}',
            style: GoogleFonts.openSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPositive ? AppColors.success : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PENJUALAN (REAL & PIUTANG)
  // ==========================================
  Widget _buildTabPenjualan() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textHint,
              tabs: [
                Tab(text: 'Uang Real (${_uangRealList.length})'),
                Tab(text: 'Piutang (${_uangPiutangList.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildKeuanganList(_uangRealList, 'UANG REAL', _totalUangReal),
                _buildKeuanganList(_uangPiutangList, 'PIUTANG', _totalUangPiutang),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeuanganList(List<Map<String, dynamic>> trxs, String type, double totalUang) {
    final isReal = type == 'UANG REAL';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          color: isReal ? Colors.blue.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.08),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReal ? 'Total Uang Real (Masuk Kas)' : 'Total Piutang (Belum Bayar)',
                    style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(totalUang),
                    style: GoogleFonts.openSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isReal ? Colors.blue.shade800 : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
              Text(
                '${trxs.length} Transaksi',
                style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: trxs.isEmpty
              ? Center(
                  child: Text('Tidak ada data transaksi $type', style: GoogleFonts.openSans(color: AppColors.textHint)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: trxs.length,
                  itemBuilder: (context, index) {
                    final trx = trxs[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      color: AppColors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(trx['id_transaksi'] ?? '', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textHint)),
                                Text(trx['tanggal'] ?? '', style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(trx['nama_pelanggan'] ?? '-', style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                Text(
                                  _formatCurrency(double.tryParse(trx['total_harga'].toString()) ?? 0),
                                  style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: isReal ? AppColors.primary : Colors.red),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${trx['total_item']} Item', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isReal ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    trx['status_bayar'] ?? '-',
                                    style: GoogleFonts.openSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isReal ? AppColors.success : Colors.orange.shade800,
                                    ),
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
    );
  }

  // ==========================================
  // TAB 3: PENGELUARAN (GAJI, OPEX, RESTOK, CAPEX)
  // ==========================================
  Widget _buildTabPengeluaran() {
    return Column(
      children: [
        // Category Selector Chips
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPengeluaranFilterChip('Semua'),
                const SizedBox(width: 8),
                _buildPengeluaranFilterChip('Gaji Terbayar (Potong Kas)'),
                const SizedBox(width: 8),
                _buildPengeluaranFilterChip('Gaji Belum Dibayar (Pending)'),
                const SizedBox(width: 8),
                _buildPengeluaranFilterChip('OPEX Harian'),
                const SizedBox(width: 8),
                _buildPengeluaranFilterChip('Restok Bahan'),
                const SizedBox(width: 8),
                _buildPengeluaranFilterChip('CAPEX (Aset Modal)'),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildPengeluaranContent(),
        ),
      ],
    );
  }

  Widget _buildPengeluaranFilterChip(String label) {
    final isSelected = _selectedPengeluaranFilter == label;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.openSans(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary),
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      onSelected: (val) {
        if (val) setState(() => _selectedPengeluaranFilter = label);
      },
    );
  }

  Widget _buildPengeluaranContent() {
    switch (_selectedPengeluaranFilter) {
      case 'Gaji Terbayar (Potong Kas)':
        return _buildListGajiTerbayar();
      case 'Gaji Belum Dibayar (Pending)':
        return _buildListGajiBelumDibayar();
      case 'OPEX Harian':
        return _buildListOpexHarian();
      case 'Restok Bahan':
        return _buildListRestokBahan();
      case 'CAPEX (Aset Modal)':
        return _buildListCapexAset();
      case 'Semua':
      default:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Gaji Karyawan Terbayar (Potong Kas)', _formatCurrency(_totalGajiTerbayar), Colors.green.shade700),
            ..._gajiTerbayarList.take(3).map((item) => _buildGajiCard(item)),
            const SizedBox(height: 16),
            _buildSectionHeader('Gaji Berjalan Belum Dibayar (Kewajiban)', _formatCurrency(_totalGajiBelumDibayar), Colors.orange.shade800),
            ..._gajiBelumDibayarList.take(3).map((item) => _buildGajiPendingCard(item)),
            const SizedBox(height: 16),
            _buildSectionHeader('OPEX Harian (Galon, Jajan, Tisu dll)', _formatCurrency(_totalBiayaOpex), Colors.purple),
            ..._opexList.take(3).map((item) => _buildOpexCard(item)),
            const SizedBox(height: 16),
            _buildSectionHeader('Restok Bahan Baku', _formatCurrency(_totalBiayaRestock), Colors.amber),
            ..._logRestockList.take(3).map((item) => _buildRestockCard(item)),
            const SizedBox(height: 16),
            _buildSectionHeader('Aset Modal CAPEX (Penyusutan Bulanan)', _formatCurrency(_totalPenyusutanCapexPerBulan), Colors.indigo),
            ..._capexList.take(3).map((item) => _buildCapexCard(item)),
          ],
        );
    }
  }

  Widget _buildSectionHeader(String title, String total, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
          Text(total, style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  // --- LIST GAJI TERBAYAR (SUDAH POTONG KAS) ---
  Widget _buildListGajiTerbayar() {
    return Column(
      children: [
        _buildSummaryHeader(
          'Total Gaji Terbayar (Otomatis Memotong Kas)',
          _totalGajiTerbayar,
          '${_gajiTerbayarList.length} Transaksi Pencairan',
          Colors.green.shade800,
        ),
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Setiap pencairan gaji di bawah ini telah otomatis memotong Saldo Kas Real secara permanen.',
                  style: GoogleFonts.openSans(fontSize: 11, color: const Color(0xFF15803D)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _gajiTerbayarList.isEmpty
              ? Center(child: Text('Belum ada riwayat penggajian terbayar', style: GoogleFonts.openSans(color: AppColors.textHint)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _gajiTerbayarList.length,
                  itemBuilder: (_, i) => _buildGajiCard(_gajiTerbayarList[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildGajiCard(Map<String, dynamic> log) {
    final nominal = double.tryParse(log['total_bayar']?.toString() ?? '0') ?? 0;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFDCFCE7),
          child: const Icon(Icons.check, color: Color(0xFF16A34A), size: 18),
        ),
        title: Row(
          children: [
            Text(log['nama_staff'] ?? '-', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
              child: Text('TERBAYAR (POTONG KAS)', style: GoogleFonts.openSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF15803D))),
            ),
          ],
        ),
        subtitle: Text('${log['tanggal'] ?? '-'} • ${log['id_log'] ?? '-'}', style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
        trailing: Text(
          '-${_formatCurrency(nominal)}',
          style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red.shade700),
        ),
      ),
    );
  }

  // --- LIST GAJI BELUM DIBAYAR (KEWAJIBAN BERJALAN) ---
  Widget _buildListGajiBelumDibayar() {
    return Column(
      children: [
        _buildSummaryHeader(
          'Total Gaji Belum Dibayar (Kewajiban Kas)',
          _totalGajiBelumDibayar,
          '${_gajiBelumDibayarList.length} Staf Menunggu Cair',
          Colors.orange.shade800,
        ),
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nominal ini BELUM memotong uang kas. Saldo kas akan otomatis terpotong saat dicairkan di menu Penggajian.',
                  style: GoogleFonts.openSans(fontSize: 11, color: const Color(0xFF92400E)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _gajiBelumDibayarList.isEmpty
              ? Center(child: Text('Tidak ada kewajiban gaji yang tertunda', style: GoogleFonts.openSans(color: AppColors.textHint)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _gajiBelumDibayarList.length,
                  itemBuilder: (_, i) => _buildGajiPendingCard(_gajiBelumDibayarList[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildGajiPendingCard(Map<String, dynamic> staff) {
    final totalGaji = double.tryParse(staff['total_gaji']?.toString() ?? '0') ?? 0;
    final uangReal = double.tryParse(staff['uang_real']?.toString() ?? '0') ?? 0;
    final uangPiutang = double.tryParse(staff['uang_piutang']?.toString() ?? '0') ?? 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFEF3C7),
          child: const Icon(Icons.schedule, color: Color(0xFFD97706), size: 18),
        ),
        title: Row(
          children: [
            Text(staff['nama_staff'] ?? '-', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
              child: Text('BELUM DIBAYAR', style: GoogleFonts.openSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
            ),
          ],
        ),
        subtitle: Text(
          'Komisi Real: ${_formatCurrency(uangReal)}  •  Piutang: ${_formatCurrency(uangPiutang)}',
          style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_formatCurrency(totalGaji), style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade800)),
            Text('Siap Cair', style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }

  Widget _buildListOpexHarian() {
    return Column(
      children: [
        _buildSummaryHeader('Total OPEX Harian', _totalBiayaOpex, '${_opexList.length} Item Pengeluaran Rutin', Colors.purple),
        Expanded(
          child: _opexList.isEmpty
              ? Center(child: Text('Belum ada data OPEX harian', style: GoogleFonts.openSans(color: AppColors.textHint)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _opexList.length,
                  itemBuilder: (_, i) => _buildOpexCard(_opexList[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildOpexCard(OpexItem item) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF3E8FF),
          child: const Icon(Icons.shopping_basket_rounded, color: Color(0xFF7E22CE), size: 20),
        ),
        title: Text(item.namaPengeluaran, style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('${item.kategori} • ${item.tanggalMasuk}', style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
        trailing: Text(
          '-${_formatCurrency(item.totalBiaya)}',
          style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple.shade800),
        ),
      ),
    );
  }

  Widget _buildListRestokBahan() {
    return Column(
      children: [
        _buildSummaryHeader('Total Restok Bahan Baku', _totalBiayaRestock, '${_logRestockList.length} Riwayat Pembelian', Colors.amber),
        Expanded(
          child: _logRestockList.isEmpty
              ? Center(child: Text('Belum ada riwayat restok bahan', style: GoogleFonts.openSans(color: AppColors.textHint)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logRestockList.length,
                  itemBuilder: (_, i) => _buildRestockCard(_logRestockList[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildRestockCard(Map<String, dynamic> item) {
    final total = double.tryParse(item['total_biaya']?.toString() ?? '0') ?? 0;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFEF3C7),
          child: const Icon(Icons.layers_rounded, color: Color(0xFFB45309), size: 20),
        ),
        title: Text(item['nama_item'] ?? '-', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('${item['qty_masuk']} qty • ${item['tanggal'] ?? '-'}', style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
        trailing: Text(
          '-${_formatCurrency(total)}',
          style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
        ),
      ),
    );
  }

  Widget _buildListCapexAset() {
    return Column(
      children: [
        _buildSummaryHeader('Total Aset Modal CAPEX', _totalNilaiAsetCapex, 'Penyusutan Bulanan: ${_formatCurrency(_totalPenyusutanCapexPerBulan)}', Colors.indigo),
        Expanded(
          child: _capexList.isEmpty
              ? Center(child: Text('Belum ada data aset CAPEX', style: GoogleFonts.openSans(color: AppColors.textHint)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _capexList.length,
                  itemBuilder: (_, i) => _buildCapexCard(_capexList[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildCapexCard(CapexItem item) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE0E7FF),
          child: const Icon(Icons.precision_manufacturing_rounded, color: Color(0xFF3730A3), size: 20),
        ),
        title: Text(item.namaBarang, style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('Harga: ${_formatCurrency(item.hargaBarang)} • Umur: ${item.umurEkonomis} bln', style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_formatCurrency(item.biayaPerBulan), style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
            Text('per bulan', style: GoogleFonts.openSans(fontSize: 10, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(String title, double amount, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      color: color.withValues(alpha: 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(_formatCurrency(amount), style: GoogleFonts.openSans(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          Text(subtitle, style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: BARANG (IN / OUT)
  // ==========================================
  Widget _buildTabBarang() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textHint,
              tabs: const [
                Tab(text: 'IN (Masuk/Dikerjakan)'),
                Tab(text: 'OUT (Keluar/Diambil)'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBarangList(_barangIn, 'IN', _totalBarangIn, _totalUangBarangIn),
                _buildBarangList(_barangOut, 'OUT', _totalBarangOut, _totalUangBarangOut),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarangList(List<Map<String, dynamic>> items, String type, int totalItems, double totalUang) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: type == 'IN' ? Colors.orange.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.08),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Item $type', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
                  Text('$totalItems Item', style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(type == 'IN' ? 'Estimasi Omzet' : 'Uang Masuk', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
                  Text(_formatCurrency(totalUang), style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold, color: type == 'IN' ? Colors.orange.shade800 : AppColors.success)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text('Tidak ada item sepatu $type', style: GoogleFonts.openSans(color: AppColors.textHint)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      color: AppColors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(item['id_transaksi'] ?? '', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textHint)),
                                Text(item['tanggal'] ?? '', style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(item['nama_treatment'] ?? '-', style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text('${item['jenis_item']} • ${item['merek']}', style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 12, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(item['nama_pelanggan'] ?? '-', style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                  ],
                                ),
                                Text(_formatCurrency(double.tryParse(item['harga_treatment'].toString()) ?? 0), style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold)),
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
    );
  }
}
