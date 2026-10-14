import 'file_download_helper.dart' as dl_helper;

class WhatsAppHelper {
  /// Format nomor telepon ke standar internasional (62xxxx)
  static String formatPhoneNumber(String raw) {
    String clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('620')) {
      clean = '62${clean.substring(3)}';
    } else if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    } else if (clean.startsWith('8')) {
      clean = '62$clean';
    }
    return clean;
  }

  /// Format nominal Rupiah
  static String formatRupiah(num nominal) {
    final s = nominal.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return 'Rp $buffer';
  }

  /// Membuat format pesan WhatsApp pesanan selesai
  static String createSelesaiMessage({
    required String namaPelanggan,
    required String idTransaksi,
    required String kodeUnik,
    required List<dynamic> items,
    required dynamic totalHarga,
    required String statusBayar,
    required String metodeBayar,
  }) {
    final buffer = StringBuffer();
    final nama = namaPelanggan.trim().isNotEmpty ? namaPelanggan.trim() : 'Kakak';

    buffer.writeln('Halo Kak *$nama*! 👋');
    buffer.writeln('Kabar baik, sepatu/barang yang dicuci di *AH SHOES* sudah *SELESAI* dan siap diambil! 👟✨');
    buffer.writeln('');
    buffer.writeln('=========================');
    buffer.writeln('📋 *RINCIAN TRANSAKSI*');
    buffer.writeln('=========================');
    buffer.writeln('• No. Transaksi : $idTransaksi');
    if (kodeUnik.isNotEmpty && kodeUnik != '-') {
      buffer.writeln('• *Kode Unik*    : *#$kodeUnik*');
    }
    buffer.writeln('');
    buffer.writeln('👟 *Detail Item:*');

    if (items.isNotEmpty) {
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final namaTreatment = item['nama_treatment']?.toString() ?? 'Treatment';
        final harga = double.tryParse(item['harga_treatment']?.toString() ?? '0') ?? 0;
        final jenis = item['jenis_item']?.toString() ?? '';
        final merek = item['merek']?.toString() ?? '';
        final warna = item['warna']?.toString() ?? '';
        final ukuran = item['ukuran']?.toString() ?? '';

        final specParts = <String>[];
        if (jenis.isNotEmpty) specParts.add(jenis);
        if (merek.isNotEmpty) specParts.add(merek);
        if (warna.isNotEmpty) specParts.add(warna);
        if (ukuran.isNotEmpty) specParts.add('Sz $ukuran');
        final spec = specParts.isNotEmpty ? ' (${specParts.join(" • ")})' : '';

        buffer.writeln('${i + 1}. *$namaTreatment*$spec');
        buffer.writeln('   Harga: ${formatRupiah(harga)}');
      }
    } else {
      buffer.writeln('• 1 Paket Perawatan Sepatu');
    }

    final totalNum = double.tryParse(totalHarga?.toString() ?? '0') ?? 0;
    buffer.writeln('');
    buffer.writeln('💰 *Total Biaya:* *${formatRupiah(totalNum)}*');
    
    final isLunas = statusBayar == 'Lunas' || statusBayar == 'Bayar Sekarang';
    if (isLunas) {
      final m = metodeBayar.isNotEmpty ? ' ($metodeBayar)' : '';
      buffer.writeln('💳 *Status Pembayaran:* *LUNAS*$m ✅');
    } else {
      buffer.writeln('💳 *Status Pembayaran:* *Belum Lunas* (Bisa dibayar saat pengambilan)');
    }

    buffer.writeln('');
    buffer.writeln('=========================');
    if (kodeUnik.isNotEmpty && kodeUnik != '-') {
      buffer.writeln('📌 *Catatan Pengambilan:*');
      buffer.writeln('Silakan tunjukkan struk atau sebutkan Kode Unik *#$kodeUnik* kepada kasir saat pengambilan sepatu.');
      buffer.writeln('');
    }
    buffer.writeln('Terima kasih telah mempercayakan perawatan sepatu Anda kepada *AH SHOES*! 🙏');

    return buffer.toString();
  }

  /// Membuka WhatsApp secara langsung (Mendukung Web browser, Android tablet & HP)
  static Future<bool> openWhatsApp({
    required String phoneNumber,
    required String message,
  }) async {
    return await dl_helper.openWhatsApp(phoneNumber, message);
  }
}
