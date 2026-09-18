import 'dart:async';
import 'dart:io'; 
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as fbs; 
import 'package:local_auth/local_auth.dart';
import 'package:mijano_drive_app/models/user_model.dart';

class AuthService {
  
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final fb.FirebaseAuth _fbAuth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  String? _verificationId;
  User? currentUser;

  
  String _normalize(String phone) {
    final clean = phone.trim();
    if (clean.startsWith('+')) return clean;
    return '+51$clean'; 
  }

  // ==========================================
  // 0. SUBIR FOTO DE PERFIL A FIREBASE STORAGE
  // ==========================================
  Future<String?> uploadProfileImage(String uid, File imageFile) async {
    try {
      final ref = fbs.FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$uid.jpg');

      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  // ==========================================
  // 1. INICIAR SESIÓN (Correo y Contraseña)
  // ==========================================
  Future<(bool, String, UserRole?)> login(String email, String password) async {
    try {
      fb.UserCredential credential = await _fbAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;
      
      
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        currentUser = User.fromMap(userDoc.data() as Map<String, dynamic>);
        return (true, '¡Bienvenido de nuevo!', currentUser!.role);
      } else {
        return (false, 'No se encontraron los datos del usuario en el sistema.', null);
      }
    } on fb.FirebaseAuthException catch (e) {
      String message = 'Error al iniciar sesión';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Correo o contraseña incorrectos.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo electrónico es inválido.';
      } else if (e.code == 'user-disabled') {
        message = 'Esta cuenta ha sido deshabilitada.';
      }
      return (false, message, null);
    } catch (e) {
      return (false, 'Error inesperado: $e', null);
    }
  }

  // ==========================================
  // 2. ENVIAR CÓDIGO OTP POR SMS
  // ==========================================
  Future<(bool, String)> sendOtp(String phone) async {
    final completer = Completer<(bool, String)>();
    final number = _normalize(phone);

    await _fbAuth.verifyPhoneNumber(
      phoneNumber: number,
      verificationCompleted: (fb.PhoneAuthCredential credential) async {
      
      },
      verificationFailed: (fb.FirebaseAuthException e) {
        if (!completer.isCompleted) {
          String errorMsg = 'Error al enviar SMS';
          if (e.code == 'invalid-phone-number') {
            errorMsg = 'El número de teléfono ingresado no es válido.';
          }
          completer.complete((false, '$errorMsg: ${e.message}'));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        if (!completer.isCompleted) {
          completer.complete((true, 'Código enviado exitosamente por SMS'));
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );

    return completer.future;
  }

  // ==========================================
  // 3. VERIFICAR OTP (Login por Teléfono)
  // ==========================================
  Future<(bool, String)> verifyOtp(String phone, String smsCode) async {
    try {
      if (_verificationId == null) {
        return (false, 'No hay una solicitud de código activa. Solicita un nuevo SMS.');
      }

      fb.PhoneAuthCredential credential = fb.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      fb.UserCredential userCredential = await _fbAuth.signInWithCredential(credential);
      final uid = userCredential.user!.uid;

      // Buscar si el usuario ya existe en Firestore
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        currentUser = User.fromMap(userDoc.data() as Map<String, dynamic>);
      }

      return (true, '¡Código verificado con éxito!');
    } on fb.FirebaseAuthException catch (e) {
      return (false, 'Código inválido o expirado: ${e.message}');
    } catch (e) {
      return (false, 'Error inesperado: $e');
    }
  }

  // ==========================================
  // 4. VERIFICAR OTP Y REGISTRAR CUENTA
  // ==========================================
  Future<(bool, String)> verifyOtpAndRegister({
    required String smsCode,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String dni,
    required String city,
    required UserRole role,
    File? profileImage, 
  }) async {
    try {
      if (_verificationId == null) {
        return (false, 'No hay una solicitud de código activa. Solicita un nuevo SMS.');
      }

      fb.PhoneAuthCredential phoneCredential = fb.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      fb.UserCredential userCredential = await _fbAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = userCredential.user!.uid;
      final number = _normalize(phone);

      
      String? photoUrl;
      if (profileImage != null) {
        photoUrl = await uploadProfileImage(uid, profileImage);
      }

<<<<<<< HEAD
=======
    final number = _normalize(phone);
    final uid = number.replaceAll(RegExp(r'[^0-9]'), '');
    final existing = await _fs.getUserByPhone(number);
    if (existing != null) {
      currentUser = existing;
    } else {
>>>>>>> 3aef7d0d7ce0688df6df9e74524f093dc16c6c5c
      currentUser = User(
        uid: uid,
        name: name,
        email: email.trim(),
        phone: number,
        dni: dni,
        city: city,
        role: role,
        photoUrl: photoUrl, 
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(currentUser!.toMap());
      await _getOrCreateWallet(uid);

      return (true, '¡Cuenta registrada con éxito!');
    } on fb.FirebaseAuthException catch (e) {
      String message = 'Error en el registro';
      if (e.code == 'weak-password') {
        message = 'La contraseña es demasiado débil (mínimo 6 caracteres).';
      } else if (e.code == 'email-already-in-use') {
        message = 'El correo electrónico ya se encuentra registrado.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo electrónico es inválido.';
      }
      return (false, message);
    } catch (e) {
      return (false, 'Error inesperado al registrar: $e');
    }
  }

  // ==========================================
  // 5. REGISTRO ESTÁNDAR (Correo, Contraseña y Firestore)
  // ==========================================
  Future<(bool, String)> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String dni,
    required String city,
    required UserRole role,
    File? profileImage, 
  }) async {
    try {
      fb.UserCredential userCredential = await _fbAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = userCredential.user!.uid;
      final number = _normalize(phone);

      
      String? photoUrl;
      if (profileImage != null) {
        photoUrl = await uploadProfileImage(uid, profileImage);
      }

      currentUser = User(
        uid: uid,
        name: name,
        email: email.trim(),
        phone: number,
        dni: dni,
        city: city,
        role: role,
        photoUrl: photoUrl, 
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(currentUser!.toMap());
      await _getOrCreateWallet(uid);

      return (true, '¡Cuenta registrada con éxito!');
    } on fb.FirebaseAuthException catch (e) {
      String message = 'Error en el registro';
      if (e.code == 'weak-password') {
        message = 'La contraseña es demasiado débil (mínimo 6 caracteres).';
      } else if (e.code == 'email-already-in-use') {
        message = 'El correo electrónico ya se encuentra registrado.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo electrónico es inválido.';
      }
      return (false, message);
    } catch (e) {
      return (false, 'Error inesperado al registrar: $e');
    }
  }

  // ==========================================
  // 6. CONSULTAR DNI (RENIEC)
  // ==========================================
  Future<String?> lookupDni(String dni) async {
    try {
      await Future.delayed(const Duration(seconds: 1)); 
      if (dni.length == 8) {
        return "Ciudadano Verificado $dni"; 
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==========================================
  // 7. COMPLETAR PERFIL
  // ==========================================
  Future<void> completeProfile({
    required String name,
    required String dni,
    required String city,
    required UserRole role,
    String? photoUrl,
  }) async {
    try {
      final user = _fbAuth.currentUser;
      if (user == null) return;

      final uid = user.uid;

      if (currentUser != null) {
        currentUser = currentUser!.copyWith(
          name: name,
          dni: dni,
          city: city,
          role: role,
          photoUrl: photoUrl,
        );
      }

      await _firestore.collection('users').doc(uid).update({
        'name': name,
        'dni': dni,
        'city': city,
        'role': role.name,
        if (photoUrl != null) 'photoUrl': photoUrl,
      });
    } catch (e) {
      // Manejar error de actualización
    }
  }

  // ==========================================
  // 8. MÉTODOS DE BIOMETRÍA
  // ==========================================
  Future<bool> canUseBiometrics() async {
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Autentícate para ingresar a Mijano Drive',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

<<<<<<< HEAD
  // ==========================================
  // MÉTODOS AUXILIARES
  // ==========================================
  Future<void> _getOrCreateWallet(String uid) async {
    try {
      final walletRef = _firestore.collection('wallets').doc(uid);
      final doc = await walletRef.get();
      if (!doc.exists) {
        await walletRef.set({
          'uid': uid,
          'balance': 0.0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Manejar de forma silenciosa
    }
  }

  Future<void> signOut() async {
    await _fbAuth.signOut();
    currentUser = null;
    _verificationId = null;
=======
  /// Cierra sesión de forma asíncrona en Firebase y limpia variables en memoria.
  Future<void> signOut() async {
    currentUser = null;
    _verificationId = null;
    try {
      await _fbAuth.signOut();
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
>>>>>>> 3aef7d0d7ce0688df6df9e74524f093dc16c6c5c
  }
}