import 'dart:convert';

class TreatmentIngredient {
  final String namaItem;
  final double qty;

  TreatmentIngredient({required this.namaItem, required this.qty});
}

class Treatment {
  final String idTreatment;
  final String namaTreatment;
  final double hargaJual;
  final String tipeFee; // 'Persentase' or 'Nominal'
  final double nilaiFee;
  final double stok;
  final List<TreatmentIngredient> bahanBaku;

  Treatment({
    required this.idTreatment,
    required this.namaTreatment,
    required this.hargaJual,
    required this.tipeFee,
    required this.nilaiFee,
    required this.stok,
    required this.bahanBaku,
  });

  factory Treatment.fromJson(Map<String, dynamic> json) {
    List<TreatmentIngredient> bahan = [];
    try {
      final String bahanStr = json['bahan_baku']?.toString() ?? '';
      if (bahanStr.startsWith('[')) {
        final List<dynamic> decoded = jsonDecode(bahanStr);
        bahan = decoded.map((e) => TreatmentIngredient(
          namaItem: e['id']?.toString() ?? '',
          qty: double.tryParse(e['qty']?.toString() ?? '0') ?? 0
        )).toList();
      } else {
        final lines = bahanStr.split('\n');
        final regex = RegExp(r'^\d+\.\s*(.+?)\s+(\d+(?:\.\d+)?)\s*$');
        for (var line in lines) {
          final match = regex.firstMatch(line.trim());
          if (match != null) {
            bahan.add(TreatmentIngredient(
              namaItem: match.group(1)!.trim(),
              qty: double.tryParse(match.group(2)!) ?? 0,
            ));
          }
        }
      }
    } catch (e) {
      print('Error parsing bahan_baku: $e');
    }

    return Treatment(
      idTreatment: json['id_treatment']?.toString() ?? '',
      namaTreatment: json['nama_treatment']?.toString() ?? '',
      hargaJual: double.tryParse(json['harga_jual']?.toString() ?? '0') ?? 0,
      tipeFee: json['tipe_fee']?.toString() ?? '',
      nilaiFee: double.tryParse(json['nilai_fee']?.toString() ?? '0') ?? 0,
      stok: double.tryParse(json['stok']?.toString() ?? '999') ?? 999,
      bahanBaku: bahan,
    );
  }
}
