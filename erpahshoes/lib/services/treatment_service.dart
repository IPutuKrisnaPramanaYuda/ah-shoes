import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/treatment_model.dart';

class TreatmentService {
  final String scriptUrl = Constants.scriptUrl;
  static List<Treatment>? _cache;

  Future<List<Treatment>> getTreatments({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null && _cache!.isNotEmpty) {
      return _cache!;
    }
    try {
      final url = Uri.parse('$scriptUrl?action=get_treatments');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List list = data['data'];
          _cache = list.map((e) => Treatment.fromJson(e)).toList();
          return _cache!;
        }
      }
    } catch (e) {
      print("Error getTreatments: $e");
    }
    return _cache ?? [];
  }

  static void invalidateCache() {
    _cache = null;
  }

  Future<bool> addTreatment(Map<String, String> treatmentData) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'add_treatment',
        ...treatmentData
      }).query;
      
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error addTreatment: $e");
    }
    return false;
  }

  Future<bool> updateTreatment(Map<String, String> treatmentData) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'update_treatment',
        ...treatmentData
      }).query;
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error updateTreatment: $e");
    }
    return false;
  }

  Future<bool> deleteTreatment(String idTreatment) async {
    try {
      String queryString = Uri(queryParameters: {
        'action': 'delete_treatment',
        'id_treatment': idTreatment,
      }).query;
      final url = Uri.parse('$scriptUrl?$queryString');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      print("Error deleteTreatment: $e");
    }
    return false;
  }
}
