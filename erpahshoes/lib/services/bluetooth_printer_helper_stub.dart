import 'printer_models.dart';

class BluetoothPrinterNativeHelper {
  static Future<bool> isBluetoothEnabled() async {
    return false;
  }

  static Future<bool> isConnected() async {
    return false;
  }

  static Future<List<PrinterDeviceInfo>> getPairedDevices() async {
    return [];
  }

  static Future<bool> connect(String macAddress) async {
    return false;
  }

  static Future<bool> disconnect() async {
    return true;
  }

  static Future<bool> writeBytes(List<int> bytes) async {
    return false;
  }

  static bool get isPlatformSupported => false;
}
