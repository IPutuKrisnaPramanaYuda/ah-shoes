import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/bluetooth_printer_service.dart';
import '../../services/printer_models.dart';
import '../../utils/app_theme.dart';

class PrinterSettingsDialog extends StatefulWidget {
  const PrinterSettingsDialog({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const PrinterSettingsDialog(),
    );
  }

  @override
  State<PrinterSettingsDialog> createState() => _PrinterSettingsDialogState();
}

class _PrinterSettingsDialogState extends State<PrinterSettingsDialog> {
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  List<PrinterDeviceInfo> _devices = [];
  bool _isLoading = true;
  bool _isConnected = false;
  String? _savedMac;
  String? _savedName;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final isConnected = await _printerService.isConnected();
    final savedMac = await _printerService.getSavedPrinterMac();
    final savedName = await _printerService.getSavedPrinterName();

    List<PrinterDeviceInfo> devices = [];
    if (_printerService.isSupported) {
      devices = await _printerService.getBondedDevices();
    }

    setState(() {
      _isConnected = isConnected;
      _savedMac = savedMac;
      _savedName = savedName;
      _devices = devices;
      _isLoading = false;
    });
  }

  Future<void> _connect(PrinterDeviceInfo device) async {
    setState(() {
      _statusMsg = 'Menghubungkan ke ${device.name}...';
      _isLoading = true;
    });

    final success = await _printerService.connect(device.macAddress, name: device.name);
    setState(() {
      _isConnected = success;
      _savedMac = device.macAddress;
      _savedName = device.name;
      _statusMsg = success ? 'Berhasil terhubung ke ${device.name}' : 'Gagal terhubung ke ${device.name}';
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_statusMsg ?? '', style: GoogleFonts.openSans()),
        backgroundColor: success ? AppColors.success : AppColors.error,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    await _printerService.disconnect();
    setState(() {
      _isConnected = false;
      _isLoading = false;
      _statusMsg = 'Printer terputus';
    });
  }

  Future<void> _testPrint() async {
    final testReceipt = ReceiptData(
      idTransaksi: 'TEST-001',
      kodeUnik: '9999',
      tanggal: '12-10-2026',
      waktu: '21:00',
      namaPelanggan: 'Tes Print',
      noHp: '08123456789',
      namaKasir: 'Admin',
      metodeBayar: 'Cash',
      statusBayar: 'Lunas',
      totalHarga: 35000,
      totalItem: 1,
      nominalUang: 50000,
      kembalian: 15000,
      items: [
        ReceiptItemData(
          namaTreatment: 'Deep Clean',
          harga: 35000,
          jenisItem: 'Sneakers',
          merek: 'Nike',
          warna: 'Putih',
          ukuran: '42',
          staffNama: 'Kasir',
        ),
      ],
    );

    final ok = await _printerService.printReceipt(testReceipt);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Test print berhasil dikirim!' : 'Gagal mengirim data ke printer',
            style: GoogleFonts.openSans()),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      title: Row(
        children: [
          const Icon(Icons.print, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Printer Bluetooth Thermal',
              style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _checkStatus,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isConnected ? AppColors.success.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isConnected ? AppColors.success.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: _isConnected ? AppColors.success : Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isConnected ? 'Terhubung' : 'Belum Terhubung',
                            style: GoogleFonts.openSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _isConnected ? AppColors.success : Colors.orange.shade800,
                            ),
                          ),
                          Text(
                            _savedName != null ? '$_savedName ($_savedMac)' : 'Pilih printer dari daftar di bawah',
                            style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'PERANGKAT PAIRED BLUETOOTH',
                style: GoogleFonts.openSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHint,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              if (!_printerService.isSupported)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Fitur Bluetooth Thermal aktif di Android Tablet. Pada Web browser digunakan simulasi struk.',
                          style: GoogleFonts.openSans(fontSize: 11, color: Colors.brown),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_devices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(Icons.devices_other, size: 36, color: AppColors.textHint),
                      const SizedBox(height: 8),
                      Text(
                        'Tidak ada printer Bluetooth yang di-pairing.',
                        style: GoogleFonts.openSans(fontSize: 12, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pastikan printer Iware sudah di-pairing (hubungkan) terlebih dahulu di menu Pengaturan Bluetooth tablet Android.',
                        style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textHint),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ..._devices.map((device) {
                  final isCurrent = _savedMac == device.macAddress && _isConnected;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isCurrent ? AppColors.primary : AppColors.border,
                        width: isCurrent ? 1.5 : 1,
                      ),
                    ),
                    color: isCurrent ? AppColors.primaryLight : AppColors.surface,
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.print,
                        color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                      ),
                      title: Text(
                        device.name.isNotEmpty ? device.name : 'Unknown Device',
                        style: GoogleFonts.openSans(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        device.macAddress,
                        style: GoogleFonts.openSans(fontSize: 11, color: AppColors.textHint),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCurrent ? AppColors.success : AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _connect(device),
                        child: Text(
                          isCurrent ? 'Terhubung' : 'Sambungkan',
                          style: GoogleFonts.openSans(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 10),
              if (_isConnected) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.print, size: 16),
                        label: Text('Tes Cetak Struk', style: GoogleFonts.openSans(fontSize: 12)),
                        onPressed: _testPrint,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _disconnect,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Putus', style: GoogleFonts.openSans(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Tutup', style: GoogleFonts.openSans(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
