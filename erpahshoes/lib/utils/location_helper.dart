import '../models/absensi_model.dart';
import 'location_helper_stub.dart'
    if (dart.library.html) 'location_helper_web.dart' as impl;

Future<LokasiHasil> ambilLokasiPerangkat() async {
  return await impl.ambilLokasiPlatformImpl();
}
