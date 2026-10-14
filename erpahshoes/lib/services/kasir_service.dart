import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class KasirService {
  final String scriptUrl = Constants.scriptUrl;

  Future<bool> addTransaksi(Map<String, String> data) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'add_transaksi',
        ...data,
      }).query;

      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        try {
          final decoded = jsonDecode(response.body);
          return decoded['status'] == 'success';
        } catch (e) {
          print('Failed to decode transaksi response: ${response.body}');
        }
      }
    } catch (e) {
      print('Error addTransaksi: $e');
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getTransaksi() async {
    try {
      final url = Uri.parse('$scriptUrl?action=get_transaksi');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      print('Error getTransaksi: $e');
    }
    return [];
  }

  Future<bool> updateStatusTransaksi(String idTrx, String status, {String? metodeBayar, String? statusBayar}) async {
    try {
      final queryParams = <String, String>{
        'action': 'update_status',
        'id_transaksi': idTrx,
        'status': status,
      };
      if (metodeBayar != null) queryParams['metode_bayar'] = metodeBayar;
      if (statusBayar != null) queryParams['status_bayar'] = statusBayar;

      final url = Uri.parse('$scriptUrl?${Uri(queryParameters: queryParams).query}');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print('Error updateStatusTransaksi: $e');
    }
    return false;
  }
}
