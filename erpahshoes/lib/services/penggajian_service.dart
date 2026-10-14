import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class PenggajianService {
  final String scriptUrl = Constants.scriptUrl;

  // In-Memory Cache untuk akses instan tanpa jeda loading
  static List<Map<String, dynamic>>? _cachedPenggajian;
  static List<Map<String, dynamic>>? _cachedLogs;

  static List<Map<String, dynamic>>? get cachedPenggajian => _cachedPenggajian;
  static List<Map<String, dynamic>>? get cachedLogs => _cachedLogs;

  Future<List<Map<String, dynamic>>> getPenggajian({bool forceRefresh = false}) async {
    try {
      final url = Uri.parse('$scriptUrl?action=get_penggajian');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _cachedPenggajian = List<Map<String, dynamic>>.from(data['data']);
          return _cachedPenggajian!;
        }
      }
    } catch (e) {
      print('Error getPenggajian: $e');
    }
    return _cachedPenggajian ?? [];
  }

  Future<List<Map<String, dynamic>>> getLogPenggajian({bool forceRefresh = false}) async {
    try {
      final url = Uri.parse('$scriptUrl?action=get_log_penggajian');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _cachedLogs = List<Map<String, dynamic>>.from(data['data']);
          return _cachedLogs!;
        }
      }
    } catch (e) {
      print('Error getLogPenggajian: $e');
    }
    return _cachedLogs ?? [];
  }

  Future<bool> bayarGaji(String namaStaff, double totalBayar) async {
    try {
      final url = Uri.parse('$scriptUrl?action=bayar_gaji&nama_staff=$namaStaff&total_bayar=$totalBayar');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        final ok = data['status'] == 'success';
        if (ok) {
          // Bersihkan cache agar data terbaru segera diambil
          _cachedPenggajian = null;
          _cachedLogs = null;
        }
        return ok;
      }
    } catch (e) {
      print('Error bayarGaji: $e');
    }
    return false;
  }

  Future<bool> updatePenggajianMaster(
    String namaStaff,
    double bpjstk,
    double thr,
    double keterlambatan, {
    double tunjangan = 0,
    double cashbon = 0,
  }) async {
    try {
      final url = Uri.parse(
        '$scriptUrl?action=update_penggajian_master&nama_staff=$namaStaff&bpjstk=$bpjstk&thr=$thr&keterlambatan=$keterlambatan&tunjangan=$tunjangan&cashbon=$cashbon',
      );
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        final ok = data['status'] == 'success';
        if (ok) {
          _cachedPenggajian = null;
        }
        return ok;
      }
    } catch (e) {
      print('Error updatePenggajianMaster: $e');
    }
    return false;
  }

  Future<Map<String, String>?> uploadSlipPdf(dynamic bytes, String fileName) async {
    try {
      final base64Pdf = base64Encode(bytes);
      final url = Uri.parse(scriptUrl);
      final response = await http.post(
        url,
        body: jsonEncode({
          'action': 'upload_slip_pdf',
          'pdf_base64': base64Pdf,
          'file_name': fileName,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return {
            'download_url': (data['download_url'] ?? '').toString(),
            'view_url': (data['view_url'] ?? '').toString(),
          };
        }
      }
    } catch (e) {
      print('Error uploadSlipPdf: $e');
    }
    return null;
  }
}
