import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'printer_models.dart';
import 'bluetooth_printer_helper_stub.dart'
    if (dart.library.io) 'bluetooth_printer_helper_native.dart';

class BluetoothPrinterService {
  static final BluetoothPrinterService _instance = BluetoothPrinterService._internal();
  factory BluetoothPrinterService() => _instance;
  BluetoothPrinterService._internal();

  static const String _prefKeyMac = 'saved_printer_mac';
  static const String _prefKeyName = 'saved_printer_name';

  bool get isSupported => BluetoothPrinterNativeHelper.isPlatformSupported;

  Future<bool> isBluetoothEnabled() async {
    return await BluetoothPrinterNativeHelper.isBluetoothEnabled();
  }

  Future<bool> isConnected() async {
    return await BluetoothPrinterNativeHelper.isConnected();
  }

  Future<List<PrinterDeviceInfo>> getBondedDevices() async {
    return await BluetoothPrinterNativeHelper.getPairedDevices();
  }

  Future<String?> getSavedPrinterMac() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyMac);
  }

  Future<String?> getSavedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyName);
  }

  Future<void> savePrinterInfo(String mac, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyMac, mac);
    await prefs.setString(_prefKeyName, name);
  }

  Future<bool> connect(String macAddress, {String? name}) async {
    final ok = await BluetoothPrinterNativeHelper.connect(macAddress);
    if (ok && name != null) {
      await savePrinterInfo(macAddress, name);
    }
    return ok;
  }

  Future<bool> autoConnect() async {
    final savedMac = await getSavedPrinterMac();
    if (savedMac == null || savedMac.isEmpty) return false;
    final connected = await isConnected();
    if (connected) return true;
    return await connect(savedMac);
  }

  Future<bool> disconnect() async {
    return await BluetoothPrinterNativeHelper.disconnect();
  }

  /// Format 2 kolom rata kiri-kanan untuk kertas 58mm (32 kolom)
  String _twoColumns(String left, String right, {int width = 32}) {
    if (left.length + right.length >= width) {
      final maxLeft = width - right.length - 1;
      if (maxLeft > 0 && left.length > maxLeft) {
        left = left.substring(0, maxLeft);
      }
    }
    final space = width - left.length - right.length;
    return left + (' ' * (space > 0 ? space : 1)) + right;
  }

  String _formatRp(int nominal) {
    final s = nominal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return 'Rp $buffer';
  }

  /// Membuat format struk ESC/POS 58mm
  Future<List<int>> generateReceiptBytes(ReceiptData data) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      // 1. Reset
      bytes += generator.reset();

      // 2. HEADER TOKO
      bytes += generator.text(
        'AH SHOES',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        'Shoe Cleaning & Care Service',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'WA: 0889-8736-1671',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text('--------------------------------');

      // 3. KODE UNIK (SANGAT MENCOLOK UNTUK IDENTIFIKASI SEPATU)
      bytes += generator.text(
        'KODE UNIK SEPATU',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += generator.text(
        '#${data.kodeUnik}',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        'Tunjukkan kode ini saat ambil sepatu',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text('--------------------------------');

      // 4. INFORMASI TRANSAKSI
      bytes += generator.text(_twoColumns('No. TRX', data.idTransaksi));
      bytes += generator.text(_twoColumns('Tgl / Jam', '${data.tanggal} ${data.waktu}'));
      if (data.namaKasir.isNotEmpty) {
        bytes += generator.text(_twoColumns('Kasir', data.namaKasir));
      }
      bytes += generator.text(_twoColumns('Pelanggan', data.namaPelanggan));
      if (data.noHp.isNotEmpty) {
        bytes += generator.text(_twoColumns('No. HP', data.noHp));
      }
      bytes += generator.text('--------------------------------');

      // 5. DETAIL ITEM / SEPATU
      bytes += generator.text(
        'DETAIL ITEM / TREATMENT',
        styles: const PosStyles(bold: true),
      );
      for (int i = 0; i < data.items.length; i++) {
        final item = data.items[i];
        final numPrefix = '${i + 1}. ';
        
        // Baris 1: Nomor + Nama Treatment & Harga
        final treatLine = _twoColumns(
          '$numPrefix${item.namaTreatment}',
          _formatRp(item.harga),
        );
        bytes += generator.text(treatLine, styles: const PosStyles(bold: true));

        // Baris 2: Merek & Jenis
        final specParts = <String>[];
        if (item.jenisItem.isNotEmpty) specParts.add(item.jenisItem);
        if (item.merek.isNotEmpty) specParts.add(item.merek);
        if (item.warna.isNotEmpty) specParts.add(item.warna);
        if (item.ukuran.isNotEmpty) specParts.add('Sz ${item.ukuran}');
        if (specParts.isNotEmpty) {
          bytes += generator.text('   ${specParts.join(" • ")}');
        }

        // Baris 3: Staff pengerjaan
        if (item.staffNama.isNotEmpty) {
          bytes += generator.text('   Staff: ${item.staffNama}');
        }
      }
      bytes += generator.text('--------------------------------');

      // 6. TOTAL & PEMBAYARAN
      bytes += generator.text(
        _twoColumns('TOTAL (${data.totalItem} Item)', _formatRp(data.totalHarga)),
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text(_twoColumns('Status Bayar', data.statusBayar));
      if (data.metodeBayar.isNotEmpty) {
        bytes += generator.text(_twoColumns('Metode Bayar', data.metodeBayar));
      }
      if (data.nominalUang != null && data.nominalUang! > 0) {
        bytes += generator.text(_twoColumns('Tunai', _formatRp(data.nominalUang!)));
      }
      if (data.kembalian != null && data.kembalian! >= 0) {
        bytes += generator.text(_twoColumns('Kembalian', _formatRp(data.kembalian!)));
      }
      bytes += generator.text('--------------------------------');

      // 7. FOOTER
      bytes += generator.text(
        'SYARAT & KETENTUAN:',
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text('1. Bawa struk / kode unik saat ambil.');
      bytes += generator.text('2. Klaim maksimal 1x24 jam.');
      bytes += generator.text('3. Pengambilan maks 30 hari.');
      bytes += generator.feed(1);
      bytes += generator.text(
        '*** TERIMA KASIH ***',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'Kepuasan Anda Prioritas Kami',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(3);
      bytes += generator.cut();

      return bytes;
    } catch (e) {
      debugPrint('Error generating ESC/POS bytes with profile: $e. Using fallback.');
      return _generateRawFallbackBytes(data);
    }
  }

  /// Fallback ESC/POS byte generator (Standar ESC/POS byte generator murni jika load profile error)
  List<int> _generateRawFallbackBytes(ReceiptData data) {
    final List<int> b = [];
    
    // ESC @ (Initialize)
    b.addAll([0x1B, 0x40]);

    // Align Center: ESC a 1
    b.addAll([0x1B, 0x61, 0x01]);
    // Double Height & Width: GS ! 0x11
    b.addAll([0x1D, 0x21, 0x11]);
    b.addAll(utf8.encode("AH SHOES\n"));
    // Normal size: GS ! 0x00
    b.addAll([0x1D, 0x21, 0x00]);
    b.addAll(utf8.encode("Shoe Cleaning & Care Service\n"));
    b.addAll(utf8.encode("WA: 0889-8736-1671\n"));
    b.addAll(utf8.encode("--------------------------------\n"));

    // Kode Unik (Bold & Large)
    b.addAll(utf8.encode("KODE UNIK SEPATU\n"));
    b.addAll([0x1D, 0x21, 0x11]);
    b.addAll(utf8.encode("#${data.kodeUnik}\n"));
    b.addAll([0x1D, 0x21, 0x00]);
    b.addAll(utf8.encode("Tunjukkan kode ini saat ambil\n"));
    b.addAll(utf8.encode("--------------------------------\n"));

    // Align Left: ESC a 0
    b.addAll([0x1B, 0x61, 0x00]);
    b.addAll(utf8.encode(_twoColumns('No. TRX', data.idTransaksi) + "\n"));
    b.addAll(utf8.encode(_twoColumns('Tgl / Jam', '${data.tanggal} ${data.waktu}') + "\n"));
    if (data.namaKasir.isNotEmpty) {
      b.addAll(utf8.encode(_twoColumns('Kasir', data.namaKasir) + "\n"));
    }
    b.addAll(utf8.encode(_twoColumns('Pelanggan', data.namaPelanggan) + "\n"));
    if (data.noHp.isNotEmpty) {
      b.addAll(utf8.encode(_twoColumns('No. HP', data.noHp) + "\n"));
    }
    b.addAll(utf8.encode("--------------------------------\n"));

    // Items
    b.addAll(utf8.encode("DETAIL ITEM:\n"));
    for (int i = 0; i < data.items.length; i++) {
      final item = data.items[i];
      b.addAll(utf8.encode(_twoColumns('${i + 1}. ${item.namaTreatment}', _formatRp(item.harga)) + "\n"));
      final spec = '${item.jenisItem} ${item.merek} ${item.warna} ${item.ukuran.isNotEmpty ? "Sz " + item.ukuran : ""}'.trim();
      if (spec.isNotEmpty) {
        b.addAll(utf8.encode("   $spec\n"));
      }
      if (item.staffNama.isNotEmpty) {
        b.addAll(utf8.encode("   Staff: ${item.staffNama}\n"));
      }
    }
    b.addAll(utf8.encode("--------------------------------\n"));

    // Total
    b.addAll(utf8.encode(_twoColumns('TOTAL (${data.totalItem} Item)', _formatRp(data.totalHarga)) + "\n"));
    b.addAll(utf8.encode(_twoColumns('Status Bayar', data.statusBayar) + "\n"));
    if (data.metodeBayar.isNotEmpty) {
      b.addAll(utf8.encode(_twoColumns('Metode', data.metodeBayar) + "\n"));
    }
    if (data.nominalUang != null && data.nominalUang! > 0) {
      b.addAll(utf8.encode(_twoColumns('Tunai', _formatRp(data.nominalUang!)) + "\n"));
    }
    if (data.kembalian != null && data.kembalian! >= 0) {
      b.addAll(utf8.encode(_twoColumns('Kembalian', _formatRp(data.kembalian!)) + "\n"));
    }
    b.addAll(utf8.encode("--------------------------------\n"));

    // Center Footer
    b.addAll([0x1B, 0x61, 0x01]);
    b.addAll(utf8.encode("Bawa struk saat ambil sepatu\n"));
    b.addAll(utf8.encode("*** TERIMA KASIH ***\n\n\n\n"));

    return b;
  }

  /// Print data struk ke printer Bluetooth yang sedang terhubung
  Future<bool> printReceipt(ReceiptData data) async {
    final bytes = await generateReceiptBytes(data);
    return await BluetoothPrinterNativeHelper.writeBytes(bytes);
  }
}
