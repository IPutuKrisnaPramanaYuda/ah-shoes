class PrinterDeviceInfo {
  final String name;
  final String macAddress;

  PrinterDeviceInfo({required this.name, required this.macAddress});
}

class ReceiptItemData {
  final String namaTreatment;
  final int harga;
  final String jenisItem;
  final String merek;
  final String warna;
  final String ukuran;
  final String staffNama;

  ReceiptItemData({
    required this.namaTreatment,
    required this.harga,
    required this.jenisItem,
    required this.merek,
    required this.warna,
    required this.ukuran,
    required this.staffNama,
  });
}

class ReceiptData {
  final String idTransaksi;
  final String kodeUnik;
  final String tanggal;
  final String waktu;
  final String namaPelanggan;
  final String noHp;
  final String namaKasir;
  final String metodeBayar;
  final String statusBayar;
  final int totalHarga;
  final int totalItem;
  final int? nominalUang;
  final int? kembalian;
  final List<ReceiptItemData> items;

  ReceiptData({
    required this.idTransaksi,
    required this.kodeUnik,
    required this.tanggal,
    required this.waktu,
    required this.namaPelanggan,
    required this.noHp,
    required this.namaKasir,
    required this.metodeBayar,
    required this.statusBayar,
    required this.totalHarga,
    required this.totalItem,
    this.nominalUang,
    this.kembalian,
    required this.items,
  });
}
