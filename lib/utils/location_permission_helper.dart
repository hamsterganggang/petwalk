import 'package:permission_handler/permission_handler.dart';

class LocationPermissionHelper {
  static Future<bool> requestLocationPermission() async {
    var status = await Permission.location.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      status = await Permission.location.request();
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }

  static Future<PermissionStatus> checkPermissionStatus() async {
    return await Permission.location.status;
  }
}
