import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:local_auth/local_auth.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

/// Autenticación por teléfono:
/// - SMS real vía Firebase Phone Auth (Firebase genera un código ALEATORIO
///   de 6 dígitos y lo envía por SMS).
/// - Si el SMS falla y [AppConfig.demoFallback] está activo, cae al código
///   demo 123456 para no quedar bloqueado en pruebas.
/// - Biometría local y usuario en Firestore.
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

  /// Envía el OTP por SMS real. Firebase crea el código aleatorio y lo manda.
  Future<(bool, String)> sendOtp(String phone) async {
    final number = _normalize(phone);
    _verificationId = null;
    final completer = Completer<(bool, String)>();

    try {
      await _fbAuth.verifyPhoneNumber(
        phoneNumber: number,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          // Auto-lectura del SMS en algunos Android: firma directo.
          try {
            await _fbAuth.signInWithCredential(credential);
          } catch (_) {}
        },
        verificationFailed: (fb.FirebaseAuthException e) {
          if (completer.isCompleted) return;
          if (AppConfig.demoFallback) {
            completer.complete(
                (true, 'No se pudo enviar SMS (${e.code}). Modo demo: usa 123456'));
          } else {
            completer.complete(
                (false, 'No se pudo enviar el SMS: ${e.message ?? e.code}'));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete((true, 'Código enviado por SMS a $number'));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete((true, 'Código enviado por SMS a $number'));
          }
        },
      );
    } catch (e) {
      if (!completer.isCompleted) {
        if (AppConfig.demoFallback) {
          completer.complete((true, 'Firebase no disponible. Modo demo: usa 123456'));
        } else {
          completer.complete((false, 'Error al enviar el código: $e'));
        }
      }
    }

    return completer.future;
  }

  /// Verifica el código. Real: lo valida contra Firebase. Demo: 123456.
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
      } catch (_) {
        // Código incorrecto o expirado → se evalúa el fallback demo abajo.
      }
    }

    if (!signedIn) {
      if (AppConfig.demoFallback && code == '123456') {
        signedIn = true;
      } else {
        return (false, 'Código incorrecto');
      }
    }

    // Buscar usuario existente o dejar el perfil por completar.
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

  /// Completa el perfil (nombre, dni, ciudad, rol) y lo guarda en Firestore.
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

  /// DNI: sin backend RENIEC, el nombre se ingresa manualmente.
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
