class InventoryItem {
  final String idItem;
  final String namaItem;
  final String jenis; // 'Bahan Baku' or 'OPEX'
  final String satuan;
  final double hargaSatuan;
  final double stok;
  final String merk;
  final String idSuplier;

  InventoryItem({
    required this.idItem,
    required this.namaItem,
    required this.jenis,
    required this.satuan,
    required this.hargaSatuan,
    required this.stok,
    required this.merk,
    required this.idSuplier,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      idItem: json['id_item']?.toString() ?? '',
      namaItem: json['nama_item']?.toString() ?? '',
      jenis: json['jenis']?.toString() ?? '',
      satuan: json['satuan']?.toString() ?? '',
      hargaSatuan: double.tryParse(json['harga_satuan']?.toString() ?? '0') ?? 0,
      stok: double.tryParse(json['stok']?.toString() ?? '0') ?? 0,
      merk: json['merk']?.toString() ?? '',
      idSuplier: json['id_suplier']?.toString() ?? '',
    );
  }
}
