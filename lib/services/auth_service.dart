import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:local_auth/local_auth.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

/// Autenticación por teléfono con impresiones de depuración explícitas para Firebase.
class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _fs = FirestoreService.instance;
  final _localAuth = LocalAuthentication();
  final fb.FirebaseAuth _fbAuth = fb.FirebaseAuth.instance;

  User? currentUser;
  String? _verificationId;

  /// Normaliza a formato internacional peruano (+51XXXXXXXXX).
  String _normalize(String phone) {
    var p = phone.replaceAll(RegExp(r'\s+'), '');
    if (p.startsWith('+')) return p;
    p = p.replaceAll(RegExp(r'[^0-9]'), '');
    return '+51$p';
  }

  /// Envía el OTP por SMS real.
  Future<(bool, String)> sendOtp(String phone) async {
    final number = _normalize(phone);
    _verificationId = null;
    final completer = Completer<(bool, String)>();

    print('=== INICIANDO SOLICITUD DE OTP EN FIREBASE ===');
    print('Número enviado: $number');

    try {
      await _fbAuth.verifyPhoneNumber(
        phoneNumber: number,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          print('=== AUTO VERIFICACIÓN COMPLETADA ===');
          try {
            await _fbAuth.signInWithCredential(credential);
          } catch (e) {
            print('Error en auto sign-in: $e');
          }
        },
        verificationFailed: (fb.FirebaseAuthException e) {
          // IMPRESIÓN DIRECTA DEL ERROR EN CONSOLA
          print('==================================================');
          print('❌ ERROR CRÍTICO DE FIREBASE AUTH AL ENVIAR SMS:');
          print('Código de error (code): ${e.code}');
          print('Mensaje completo (message): ${e.message}');
          print('Detalles (plugin): ${e.plugin}');
          print('==================================================');

          if (completer.isCompleted) return;

          // Forzamos la devolución del error REAL a la pantalla
          completer.complete(
            (false, 'Error Firebase (${e.code}): ${e.message ?? "Sin mensaje"}'),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          print('=== CÓDIGO SENT / SMS ENVIADO ===');
          print('VerificationId recibido: $verificationId');
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete((true, 'Código enviado por SMS a $number'));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('=== AUTO RETRIEVAL TIMEOUT ===');
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete((true, 'Código enviado por SMS a $number'));
          }
        },
      );
    } catch (e) {
      print('❌ EXCEPCIÓN NO CAPTURADA EN VERIFYPHONENUMBER: $e');
      if (!completer.isCompleted) {
        completer.complete((false, 'Excepción al intentar enviar SMS: $e'));
      }
    }

    return completer.future;
  }

  /// Verifica el código.
  Future<(bool, String)> verifyOtp(String phone, String code) async {
    bool signedIn = false;

    if (_verificationId != null) {
      try {
        final credential = fb.PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );
        await _fbAuth.signInWithCredential(credential);
        signedIn = true;
      } catch (e) {
        print('Error al verificar código con Firebase: $e');
      }
    }

    if (!signedIn) {
      if (AppConfig.demoFallback && code == '123456') {
        signedIn = true;
      } else {
        return (false, 'Código incorrecto');
      }
    }

    // Buscar usuario existente o crear perfil base.
    final number = _normalize(phone);
    final uid = number.replaceAll(RegExp(r'[^0-9]'), '');
    final existing = await _fs.getUserByPhone(number);
    if (existing != null) {
      currentUser = existing;
    } else {
      currentUser = User(
        uid: uid,
        phone: number,
        role: UserRole.passenger,
        createdAt: DateTime.now(),
      );
    }
    return (true, 'ok');
  }

  Future<void> completeProfile({
    required String name,
    String? dni,
    String? city,
    UserRole role = UserRole.passenger,
    String? photoUrl,
  }) async {
    final base = currentUser;
    if (base == null) return;
    currentUser = base.copyWith(
      name: name,
      dni: dni,
      city: city,
      role: role,
      photoUrl: photoUrl,
    );
    await _fs.saveUser(currentUser!);
    await _fs.getOrCreateWallet(currentUser!.uid);
  }

  Future<String?> lookupDni(String dni) async => null;

  // ---- Biometría ----
  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Confirma tu identidad para entrar a Mijano Drive',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  void signOut() {
    currentUser = null;
    try {
      _fbAuth.signOut();
    } catch (_) {}
  }
}