import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'log_service.dart';

class SecurityService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricsAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e, st) {
      LogService.error('SecurityService', 'isBiometricsAvailable error', e, st);
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Authenticate to access your EmptyPocket vault'}) async {
    try {
      final isAvailable = await isBiometricsAvailable();
      if (!isAvailable) {
        LogService.warning('SecurityService', 'No biometric/PIN credentials available on device. Authentication denied.');
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException catch (e, st) {
      LogService.error('SecurityService', 'PlatformException during authentication', e, st);
      return false;
    } catch (e, st) {
      LogService.error('SecurityService', 'Unexpected error during authentication', e, st);
      return false;
    }
  }
}
