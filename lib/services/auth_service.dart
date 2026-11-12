import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as fbs;
import 'package:local_auth/local_auth.dart';
import 'package:mijano_drive_app/models/user_model.dart';
import '../models/tariff_model.dart';
import 'firestore_service.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final fb.FirebaseAuth _fbAuth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  String? _verificationId;
  User? currentUser;

  String _normalize(String phone) {
    final clean = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('51') && clean.length > 9) return '+$clean';
    return '+51$clean';
  }

  // ==========================================
  // 0. SUBIR FOTO DE PERFIL A FIREBASE STORAGE
  // ==========================================
  Future<String?> uploadProfileImage(String uid, File imageFile) async {
    try {
      final ref = fbs.FirebaseStorage.instance
          .ref()
          .child('drivers')
          .child(uid)
          .child('$uid.jpg');

      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  // ==========================================
  // BUSCADOR INTELIGENTE DE USUARIO POR TELÉFONO
  // ==========================================
  Future<DocumentSnapshot<Map<String, dynamic>>?> findUserDocByPhone(String phone) async {
    final cleanPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return null;

    final variants = <String>{
      cleanPhone,
      if (!cleanPhone.startsWith('+')) '+51$cleanPhone',
      if (cleanPhone.startsWith('51') && cleanPhone.length > 9) cleanPhone.substring(2),
    };

    // 1. Probar phone_index
    for (final variant in variants) {
      try {
        final indexDoc = await _firestore.collection('phone_index').doc(variant).get();
        if (indexDoc.exists) {
          final uid = indexDoc.data()?['uid'];
          if (uid is String && uid.isNotEmpty) {
            final userDoc = await _firestore.collection('users').doc(uid).get();
            if (userDoc.exists) return userDoc;
          }
        }
      } catch (_) {}
    }

    // 2. Probar colección users
    for (final variant in variants) {
      try {
        final query = await _firestore
            .collection('users')
            .where('phone', isEqualTo: variant)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          return query.docs.first;
        }
      } catch (_) {}
    }

    return null;
  }

  // ==========================================
  // 1. INICIAR SESIÓN (Correo o Teléfono y Contraseña)
  // ==========================================
  Future<(bool, String, UserRole?, String?)> login(
    String emailOrPhone,
    String password,
  ) async {
    try {
      String resolvedEmail = emailOrPhone.trim();
      String? cleanPhone;

      if (!resolvedEmail.contains('@')) {
        cleanPhone = resolvedEmail.replaceAll(RegExp(r'\D'), '');
        if (cleanPhone.isNotEmpty) {
          final userDoc = await findUserDocByPhone(cleanPhone);
          if (userDoc != null && userDoc.data() != null) {
            final docData = userDoc.data()!;
            final authEmail = (docData['authEmail'] ?? docData['email']) as String?;
            if (authEmail != null && authEmail.isNotEmpty) {
              resolvedEmail = authEmail;
            } else {
              resolvedEmail = '$cleanPhone@pasajero.mijanodrive.com';
            }
          } else {
            resolvedEmail = '$cleanPhone@pasajero.mijanodrive.com';
          }
        }
      }

      fb.UserCredential? credential;
      try {
        credential = await _fbAuth.signInWithEmailAndPassword(
          email: resolvedEmail,
          password: password,
        );
      } catch (loginErr) {
        if (cleanPhone != null && cleanPhone.isNotEmpty) {
          final fallbacks = [
            '$cleanPhone@auth.mijanodrive.com',
            '$cleanPhone@pasajero.mijanodrive.com',
          ];
          for (final altEmail in fallbacks) {
            if (altEmail != resolvedEmail) {
              try {
                credential = await _fbAuth.signInWithEmailAndPassword(
                  email: altEmail,
                  password: password,
                );
                break;
              } catch (_) {}
            }
          }
        }
        if (credential == null) rethrow;
      }

      final uid = credential.user!.uid;
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists && cleanPhone != null && cleanPhone.isNotEmpty) {
        final altDoc = await findUserDocByPhone(cleanPhone);
        if (altDoc != null && altDoc.exists) {
          userDoc = altDoc;
        }
      }

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;

        if (data['isBlocked'] == true) {
          await _fbAuth.signOut();
          return (
            false,
            'Tu cuenta ha sido bloqueada. Comunícate con el soporte de Mijano Drive.',
            null,
            null,
          );
        }

        currentUser = User.fromMap(data);
        unawaited(syncCarDriverToPublicIndex(currentUser!));

        String? status =
            data['status'] ??
            (currentUser!.role == UserRole.driver ? 'pending' : 'approved');

        return (true, '¡Bienvenido de nuevo!', currentUser!.role, status);
      } else {
        return (
          false,
          'No se encontraron los datos del usuario en el sistema.',
          null,
          null,
        );
      }
    } on fb.FirebaseAuthException catch (e) {
      String message = 'Error al iniciar sesión';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Correo o contraseña incorrectos.';
      } else if (e.code == 'too-many-requests') {
        message =
            'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
      } else if (e.code == 'network-request-failed') {
        message = 'Sin conexión. Revisa tu internet.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo electrónico es inválido.';
      } else if (e.code == 'user-disabled') {
        message = 'Esta cuenta ha sido deshabilitada.';
      }
      return (false, message, null, null);
    } catch (e) {
      return (false, 'Error inesperado: $e', null, null);
    }
  }

  // ==========================================
  // 1.1 RECUPERACIÓN DE CONTRASEÑA POR EMAIL
  // ==========================================
  // ==========================================
  // 1.0 AUTO-LOGIN / RESTAURAR SESIÓN ACTIVA
  // ==========================================
  Future<User?> tryAutoLogin() async {
    try {
      final fbUser = _fbAuth.currentUser;
      if (fbUser == null) {
        currentUser = null;
        return null;
      }

      final userDoc = await _firestore.collection('users').doc(fbUser.uid).get();
      if (!userDoc.exists) {
        await _fbAuth.signOut();
        currentUser = null;
        return null;
      }

      final data = userDoc.data() as Map<String, dynamic>;
      if (data['isBlocked'] == true) {
        await _fbAuth.signOut();
        currentUser = null;
        return null;
      }

      currentUser = User.fromMap(data);
      unawaited(syncCarDriverToPublicIndex(currentUser!));
      return currentUser;
    } catch (e) {
      return null;
    }
  }

  Future<(bool, String)> sendPasswordResetEmail(String email) async {
    try {
      final cleanEmail = email.trim();
      if (cleanEmail.isEmpty) {
        return (false, 'Ingresa tu correo electrónico.');
      }
      final emailRegex =
          RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
      if (!emailRegex.hasMatch(cleanEmail)) {
        return (
          false,
          'Ingresa un correo electrónico válido (ej. usuario@gmail.com).',
        );
      }

      await _fbAuth.sendPasswordResetEmail(email: cleanEmail);
      return (
        true,
        'Hemos enviado un enlace de recuperación a $cleanEmail. Revisa tu bandeja de entrada o spam.',
      );
    } on fb.FirebaseAuthException catch (e) {
      String message = 'Error al enviar el correo de recuperación';
      if (e.code == 'user-not-found') {
        message = 'No se encontró ninguna cuenta registrada con este correo.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo es inválido.';
      } else if (e.code == 'too-many-requests') {
        message =
            'Demasiados intentos. Espera unos minutos antes de volver a solicitarlo.';
      }
      return (false, message);
    } catch (e) {
      return (false, 'Error inesperado: $e');
    }
  }

  // ==========================================
  // 1.1.1 RECUPERACIÓN DE CONTRASEÑA POR SMS (TELÉFONO)
  // ==========================================
  Future<(bool, String)> sendPasswordResetOtp(String phone) async {
    final cleanPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty || (cleanPhone.length != 9 && !cleanPhone.startsWith('51'))) {
      return (false, 'Ingresa un número de celular válido de 9 dígitos.');
    }

    final userDoc = await findUserDocByPhone(cleanPhone);
    if (userDoc == null) {
      return (false, 'Este número no se encuentra registrado en Mijano Drive.');
    }

    return await sendOtp(cleanPhone);
  }

  Future<(bool, String)> resetPasswordWithOtp({
    required String phone,
    required String smsCode,
    required String newPassword,
  }) async {
    try {
      if (_verificationId == null) {
        return (
          false,
          'No hay una solicitud de código activa. Solicita un nuevo SMS.',
        );
      }

      final cleanCode = smsCode.trim();
      if (cleanCode.length != 6) {
        return (false, 'Ingresa el código de 6 dígitos enviado por SMS.');
      }

      if (newPassword.length < 6) {
        return (false, 'La nueva contraseña debe tener al menos 6 caracteres.');
      }

      final cleanPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
      final userDoc = await findUserDocByPhone(cleanPhone);
      if (userDoc == null || userDoc.data() == null) {
        return (
          false,
          'No se encontró una cuenta asociada a este número en el sistema.',
        );
      }

      final originalUid = userDoc.id;
      final originalData = Map<String, dynamic>.from(userDoc.data()!);

      // 1. Verificar credencial de teléfono en Firebase Auth
      final phoneCred = fb.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: cleanCode,
      );

      final userCredential = await _fbAuth.signInWithCredential(phoneCred);
      final authUser = userCredential.user!;
      final newUid = authUser.uid;

      // 2. Establecer la nueva contraseña para la cuenta
      await authUser.updatePassword(newPassword);

      // 3. Configurar authEmail para permitir login unificado con contraseña
      final authEmail = '$cleanPhone@auth.mijanodrive.com';
      try {
        await authUser.verifyBeforeUpdateEmail(authEmail);
      } catch (_) {}

      // 4. Sincronizar Firestore si el UID cambió
      if (newUid != originalUid) {
        originalData['uid'] = newUid;
        originalData['authEmail'] = authEmail;
        originalData['authUid'] = newUid;

        await _firestore.collection('users').doc(newUid).set(originalData, SetOptions(merge: true));

        // Actualizar phone_index para apuntar al nuevo UID
        await _firestore.collection('phone_index').doc(cleanPhone).set({
          'uid': newUid,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _firestore.collection('phone_index').doc('+51$cleanPhone').set({
          'uid': newUid,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final dni = originalData['dni']?.toString();
        if (dni != null && dni.isNotEmpty) {
          await _firestore.collection('dni_index').doc(dni).set({
            'uid': newUid,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        await _firestore.collection('users').doc(originalUid).update({
          'migratedTo': newUid,
          'authUid': newUid,
          'authEmail': authEmail,
        }).catchError((_) {});
      } else {
        await _firestore.collection('users').doc(originalUid).update({
          'authEmail': authEmail,
        }).catchError((_) {});
      }

      // 5. Cargar usuario actual en sesión
      final updatedDoc = await _firestore.collection('users').doc(newUid).get();
      if (updatedDoc.exists) {
        currentUser = User.fromMap(updatedDoc.data()!);
        unawaited(syncCarDriverToPublicIndex(currentUser!));
      }

      return (true, '¡Contraseña restablecida exitosamente!');
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        return (false, 'El código SMS ingresado es incorrecto.');
      } else if (e.code == 'session-expired') {
        return (false, 'El código SMS ha expirado. Solicita un nuevo código.');
      }
      return (false, 'Error de verificación: ${e.message}');
    } catch (e) {
      return (false, 'Error al cambiar contraseña: $e');
    }
  }

  // ==========================================
  // 1.2 VALIDACIÓN / VERIFICACIÓN DE EMAIL
  // ==========================================
  Future<(bool, String)> sendEmailVerification() async {
    try {
      final user = _fbAuth.currentUser;
      if (user == null) {
        return (false, 'No hay ninguna sesión activa para verificar.');
      }
      if (user.emailVerified) {
        return (true, 'Tu correo ya se encuentra verificado.');
      }
      await user.sendEmailVerification();
      return (
        true,
        'Correo de verificación enviado a ${user.email}. Por favor revisa tu bandeja de entrada o spam.',
      );
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        return (
          false,
          'Demasiadas solicitudes. Espera un momento antes de volver a intentar.',
        );
      }
      return (false, 'Error al enviar verificación: ${e.message}');
    } catch (e) {
      return (false, 'Error al enviar verificación: $e');
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
      verificationCompleted: (fb.PhoneAuthCredential credential) async {},
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
        return (
          false,
          'No hay una solicitud de código activa. Solicita un nuevo SMS.',
        );
      }

      fb.PhoneAuthCredential credential = fb.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      fb.UserCredential userCredential = await _fbAuth.signInWithCredential(
        credential,
      );
      final uid = userCredential.user!.uid;

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        currentUser = User.fromMap(userDoc.data() as Map<String, dynamic>);
        unawaited(syncCarDriverToPublicIndex(currentUser!));
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
    DateTime? birthDate,
    int? age,
    File? profileImage,
    String? vehiclePlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleYear,
    String? vehicleType,
    String? agencyName,
    String? licenseNumber,
  }) async {
    try {
      if (_verificationId == null) {
        return (
          false,
          'No hay una solicitud de código activa. Solicita un nuevo SMS.',
        );
      }

      return await _createAccountInFirebase(
        name: name,
        email: email,
        password: password,
        phone: phone,
        dni: dni,
        city: city,
        role: role,
        birthDate: birthDate,
        age: age,
        profileImage: profileImage,
        vehiclePlate: vehiclePlate,
        vehicleBrand: vehicleBrand,
        vehicleModel: vehicleModel,
        vehicleColor: vehicleColor,
        vehicleYear: vehicleYear,
        vehicleType: vehicleType,
        agencyName: agencyName,
        licenseNumber: licenseNumber,
        smsCode: smsCode,
      );
    } on fb.FirebaseAuthException catch (e) {
      return (false, 'Código inválido o expirado: ${e.message}');
    } catch (e) {
      return (false, 'Error inesperado: $e');
    }
  }

  // ==========================================
  // 5. REGISTRO ESTÁNDAR (Correo y Contraseña)
  // ==========================================
  Future<(bool, String)> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String dni,
    required String city,
    required UserRole role,
    DateTime? birthDate,
    int? age,
    File? profileImage,
    String? vehiclePlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleYear,
    String? vehicleType,
    String? agencyName,
    String? licenseNumber,
  }) async {
    return await _createAccountInFirebase(
      name: name,
      email: email,
      password: password,
      phone: phone,
      dni: dni,
      city: city,
      role: role,
      birthDate: birthDate,
      age: age,
      profileImage: profileImage,
      vehiclePlate: vehiclePlate,
      vehicleBrand: vehicleBrand,
      vehicleModel: vehicleModel,
      vehicleColor: vehicleColor,
      vehicleYear: vehicleYear,
      vehicleType: vehicleType,
      agencyName: agencyName,
      licenseNumber: licenseNumber,
    );
  }

  // ==========================================
  // MÉTODOS DE VALIDACIÓN DE DUPLICADOS
  // ==========================================
  Future<bool> isEmailRegistered(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;

    // 1. Comprobación directa y autoritativa contra Firebase Auth Identity Toolkit REST API
    // (Inmune a la protección de enumeración de correo de Google que hace que fetchSignInMethodsForEmail devuelva vacío)
    try {
      final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
      final url = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'password': 'TempDummyValidationPassword#2026',
          'returnSecureToken': true,
        }),
      );

      if (response.statusCode == 400) {
        final body = jsonDecode(response.body);
        final message = body['error']?['message']?.toString() ?? '';
        if (message.contains('EMAIL_EXISTS')) {
          return true;
        }
      } else if (response.statusCode == 200) {
        // El correo no existía y se creó temporalmente. Lo eliminamos inmediatamente sin dejar rastro.
        final body = jsonDecode(response.body);
        final idToken = body['idToken']?.toString();
        if (idToken != null) {
          final deleteUrl = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$apiKey');
          unawaited(http.post(
            deleteUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          ));
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error verificando correo en Identity Toolkit: ');
    }

    // 2. Fallback de índice en Firestore
    try {
      final doc = await _firestore.collection('email_index').doc(cleanEmail).get();
      if (doc.exists) return true;
    } catch (_) {}

    return false;
  }

  Future<bool> isPhoneRegistered(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) return false;

    // Generar variantes para buscar tanto con 9 dígitos como con +51
    final variants = <String>{
      cleanPhone,
      if (!cleanPhone.startsWith('+')) '+51$cleanPhone',
      if (cleanPhone.startsWith('+51')) cleanPhone.substring(3),
    };

    for (final variant in variants) {
      try {
        final doc = await _firestore.collection('phone_index').doc(variant).get();
        if (doc.exists) return true;
      } catch (_) {}
    }

    return false;
  }

  Future<bool> isDniRegistered(String dni) async {
    final cleanDni = dni.trim();
    if (cleanDni.isEmpty) return false;
    try {
      final doc = await _firestore.collection('dni_index').doc(cleanDni).get();
      if (doc.exists) return true;
    } catch (_) {}
    return false;
  }

  Future<bool> isLicenseRegistered(String license) async {
    final clean = license.trim().toUpperCase();
    if (clean.isEmpty) return false;
    try {
      final doc = await _firestore.collection('license_index').doc(clean).get();
      if (doc.exists) return true;
    } catch (_) {}
    return false;
  }

  Future<bool> isPlateRegistered(String plate) async {
    final clean = plate.trim().toUpperCase();
    if (clean.isEmpty) return false;
    try {
      final doc = await _firestore.collection('plate_index').doc(clean).get();
      if (doc.exists) return true;
    } catch (_) {}
    return false;
  }

  // ==========================================
  // MÉTODO PRIVADO UNIFICADO
  // ==========================================
  Future<(bool, String)> _createAccountInFirebase({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String dni,
    required String city,
    required UserRole role,
    DateTime? birthDate,
    int? age,
    File? profileImage,
    String? vehiclePlate,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleYear,
    String? vehicleType,
    String? agencyName,
    String? licenseNumber,
    String? smsCode,
  }) async {
    try {
      final cleanDni = dni.trim();
      final cleanPlate = vehiclePlate?.trim().toUpperCase();
      final cleanLicense = licenseNumber?.trim().toUpperCase();

      final cleanEmail = email.trim();
      final cleanPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
      final effectiveEmail = cleanEmail.isEmpty
          ? '$cleanPhone@pasajero.mijanodrive.com'
          : cleanEmail;

      if (cleanEmail.isNotEmpty && await isEmailRegistered(cleanEmail)) {
        return (false, 'Este correo electrónico ya está registrado.');
      }
      if (await isPhoneRegistered(phone)) {
        return (false, 'Este número ya está registrado.');
      }
      if (cleanDni.isNotEmpty && await isDniRegistered(cleanDni)) {
        return (false, 'Este DNI ya está registrado.');
      }
      if (role == UserRole.driver) {
        if (cleanLicense != null &&
            cleanLicense.isNotEmpty &&
            await isLicenseRegistered(cleanLicense)) {
          return (false, 'Este número de licencia ya está registrado.');
        }
        if (cleanPlate != null &&
            cleanPlate.isNotEmpty &&
            await isPlateRegistered(cleanPlate)) {
          return (false, 'Esta placa de vehículo ya está registrada.');
        }
      }

      fb.UserCredential userCredential = await _fbAuth
          .createUserWithEmailAndPassword(
            email: effectiveEmail,
            password: password,
          );

      final uid = userCredential.user!.uid;
      final number = _normalize(phone);

      // Vincular credencial de teléfono si se proporcionó código SMS
      if (_verificationId != null && smsCode != null && smsCode.trim().isNotEmpty) {
        try {
          final phoneCred = fb.PhoneAuthProvider.credential(
            verificationId: _verificationId!,
            smsCode: smsCode.trim(),
          );
          await userCredential.user?.linkWithCredential(phoneCred);
        } catch (linkError) {
          debugPrint('Aviso linkWithCredential al registrar: $linkError');
          if (linkError is fb.FirebaseAuthException &&
              (linkError.code == 'invalid-verification-code' ||
               linkError.code == 'session-expired')) {
            try {
              await userCredential.user?.delete();
            } catch (_) {}
            return (false, 'El código SMS ingresado es incorrecto.');
          }
        }
      }

      String? photoUrl;
      if (profileImage != null) {
        photoUrl = await uploadProfileImage(uid, profileImage);
      }

      final initialStatus = (role == UserRole.driver) ? 'pending' : 'approved';

      currentUser = User(
        uid: uid,
        name: name,
        email: cleanEmail.isNotEmpty ? cleanEmail : effectiveEmail,
        phone: number,
        dni: cleanDni.isNotEmpty ? cleanDni : null,
        city: city,
        role: role,
        birthDate: birthDate,
        age: age,
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
        status: initialStatus,
        vehiclePlate: cleanPlate,
        vehicleBrand: vehicleBrand,
        vehicleModel: vehicleModel,
        vehicleColor: vehicleColor,
        vehicleYear: vehicleYear,
        vehicleType: vehicleType,
        agencyName: agencyName,
        licenseNumber: cleanLicense,
      );

      final userData = currentUser!.toMap();
      userData['authEmail'] = effectiveEmail;

      if (role == UserRole.driver) {
        userData['documents'] = [
          {
            'id': 'dni',
            'name': 'Documento de Identidad (DNI)',
            'status': 'pending',
            'url': '',
          },
          {
            'id': 'license',
            'name': 'Licencia de Conducir',
            'status': 'pending',
            'url': '',
          },
          {
            'id': 'soat',
            'name': 'SOAT / Seguro del Vehículo',
            'status': 'pending',
            'url': '',
          },
        ];
      }

      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(uid);

      batch.set(userRef, userData);

      // 0. Índice de Email
      if (cleanEmail.isNotEmpty) {
        final emailRef = _firestore.collection('email_index').doc(cleanEmail.toLowerCase());
        batch.set(emailRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 1. Índice de DNI
      if (cleanDni.isNotEmpty) {
        final dniRef = _firestore.collection('dni_index').doc(cleanDni);
        batch.set(dniRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Índice de Teléfono (ambas variantes: local e internacional)
      if (cleanPhone.isNotEmpty) {
        final phoneRef1 = _firestore.collection('phone_index').doc(cleanPhone);
        batch.set(phoneRef1, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        final phoneRef2 = _firestore.collection('phone_index').doc('+51$cleanPhone');
        batch.set(phoneRef2, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Índice de Licencia (Si es conductor)
      if (role == UserRole.driver && cleanLicense != null && cleanLicense.isNotEmpty) {
        final licenseRef = _firestore.collection('license_index').doc(cleanLicense);
        batch.set(licenseRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 4. Índice de Placa (Si es conductor)
      if (role == UserRole.driver && cleanPlate != null && cleanPlate.isNotEmpty) {
        final plateRef = _firestore.collection('plate_index').doc(cleanPlate);
        batch.set(plateRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (currentUser != null) {
        unawaited(syncCarDriverToPublicIndex(currentUser!));
      }

      // Enviar correo de verificación automáticamente solo si tiene correo real
      if (cleanEmail.isNotEmpty) {
        try {
          await userCredential.user?.sendEmailVerification();
        } catch (_) {}
      }

      await _getOrCreateWallet(uid);

      final successMsg = (role == UserRole.driver && cleanEmail.isNotEmpty)
          ? '¡Cuenta registrada con éxito! Te hemos enviado un correo de validación.'
          : '¡Cuenta registrada con éxito!';

      return (true, successMsg);
    } on fb.FirebaseAuthException catch (e) {
      String message = 'Error en el registro';
      if (e.code == 'weak-password') {
        message = 'La contraseña es demasiado débil (mínimo 6 caracteres).';
      } else if (e.code == 'email-already-in-use') {
        message = 'El correo electrónico ya se encuentra registrado.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo electrónico es inválido.';
      } else if (e.code == 'network-request-failed') {
        message = 'Sin conexión. Revisa tu internet.';
      }
      return (false, message);
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        final user = _fbAuth.currentUser;
        if (user != null) {
          try {
            await user.delete();
          } catch (_) {}
          await _fbAuth.signOut();
        }
        return (false, 'Este DNI ya está registrado.');
      }
      return (false, 'Error inesperado al registrar: $e');
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

      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(uid);
      final dniRef = _firestore.collection('dni_index').doc(dni);

      batch.update(userRef, {
        'name': name,
        'dni': dni,
        'city': city,
        'role': role.name,
        ...? (photoUrl != null ? {'photoUrl': photoUrl} : null),
      });

      batch.set(dniRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw Exception('DNI ya registrado en otra cuenta.');
      }
      throw Exception(e);
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
    } catch (_) {}
  }

  Future<void> signOut() async {
    final uid = _fbAuth.currentUser?.uid;
    if (uid != null) {
      try {
        await _firestore.collection('drivers').doc(uid).set({
          'isAvailable': false,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    await _fbAuth.signOut();
    currentUser = null;
    _verificationId = null;
  }

  Future<void> deleteAccount() async {
    final authUser = _fbAuth.currentUser;
    if (authUser == null) {
      throw StateError('No hay una sesión activa para eliminar.');
    }

    final uid = authUser.uid;
    final userRef = _firestore.collection('users').doc(uid);
    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data();

    DocumentReference<Map<String, dynamic>>? dniRef;
    DocumentSnapshot<Map<String, dynamic>>? dniSnapshot;
    final dni = userData?['dni'];
    if (dni is String && dni.isNotEmpty) {
      dniRef = _firestore.collection('dni_index').doc(dni);
      dniSnapshot = await dniRef.get();
    }

    final profileImageRef = fbs.FirebaseStorage.instance
        .ref()
        .child('drivers')
        .child(uid)
        .child('$uid.jpg');

    final deletionBatch = _firestore.batch();
    if (userSnapshot.exists) deletionBatch.delete(userRef);
    if (dniRef != null &&
        dniSnapshot?.exists == true &&
        dniSnapshot?.data()?['uid'] == uid) {
      deletionBatch.delete(dniRef);
    }
    await deletionBatch.commit();

    try {
      try {
        await profileImageRef.delete();
      } on fbs.FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
      await authUser.delete();
    } catch (error, stackTrace) {
      try {
        final rollbackBatch = _firestore.batch();
        if (userSnapshot.exists && userData != null) {
          rollbackBatch.set(userRef, userData);
        }
        final dniData = dniSnapshot?.data();
        if (dniRef != null && dniSnapshot?.exists == true && dniData != null) {
          rollbackBatch.set(dniRef, dniData);
        }
        await rollbackBatch.commit();
      } catch (rollbackError) {
        throw StateError(
          'No se pudo eliminar la cuenta y tampoco restaurar sus datos: $rollbackError',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    currentUser = null;
  }

  /// Sincroniza el auto del conductor (cuando se registró con Carro / Auto)
  /// hacia `plate_index/CAR_VEHICLE_{uid}` e `intercity_vehicles/{uid}` para que
  /// aparezca inmediatamente en "Autos Disponibles" de los pasajeros.
  Future<void> syncCarDriverToPublicIndex(User user) async {
    if (user.role != UserRole.driver || user.uid.isEmpty) return;

    final rawType = (user.vehicleType ?? '').trim().toLowerCase();
    final hasAgency =
        user.agencyName != null && user.agencyName!.trim().isNotEmpty;
    final isMoto = rawType.contains('moto');
    final isCar =
        !isMoto &&
        (rawType == 'carro' ||
            rawType == 'auto' ||
            rawType.contains('carro') ||
            rawType.contains('auto') ||
            hasAgency);
    if (!isCar) return;

    final brand = (user.vehicleBrand ?? '').trim();
    final model = (user.vehicleModel ?? '').trim();
    String fullModel = '$brand $model'.trim();
    if (brand.isNotEmpty &&
        model.toLowerCase().startsWith(brand.toLowerCase())) {
      fullModel = model;
    }
    if (fullModel.isEmpty) {
      fullModel = 'Auto Interprovincial';
    }

    double defaultSeatPrice = PricingSettings.defaultCarPricePerSeat;
    try {
      final pricing = await FirestoreService.instance.getPricingSettings();
      defaultSeatPrice = pricing.carPricePerSeat;
    } catch (_) {}

    final plate = (user.vehiclePlate ?? '').trim().toUpperCase();
    final indexRef = _firestore
        .collection('plate_index')
        .doc('CAR_VEHICLE_${user.uid}');
    DocumentSnapshot<Map<String, dynamic>>? existingSnap;
    try {
      existingSnap = await indexRef.get();
    } catch (_) {}

    final existingSeatPrice = (existingSnap?.data()?['pricePerSeat'] as num?)?.toDouble();

    final baseProfile = <String, dynamic>{
      'id': user.uid,
      'driverId': user.uid,
      'driverName': (user.name != null && user.name!.trim().isNotEmpty)
          ? user.name!.trim()
          : 'Conductor Mijano',
      'driverPhone': user.phone,
      'vehicleBrand': brand,
      'vehicleModel': fullModel,
      'vehiclePlate': plate.isNotEmpty ? plate : 'SIN-PLACA',
      'vehicleType': 'Carro',
      'agencyName': user.agencyName ?? '',
      'avatarUrl': user.photoUrl ?? '',
      'originCity': (user.city != null && user.city!.trim().isNotEmpty)
          ? user.city!.trim()
          : 'Tarapoto',
      'destinationCity': 'Yurimaguas',
      'departureLabel': 'Hoy, 14:30',
      'pricePerSeat': existingSeatPrice ?? defaultSeatPrice,
      'isIntercityCar': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (existingSnap == null || !existingSnap.exists) {
        baseProfile['seatStates'] = {
          '1': 'available',
          '2': 'available',
          '3': 'available',
          '4': 'available',
        };
        baseProfile['seatPassengers'] = <String, dynamic>{};
        baseProfile['pendingRequests'] = <Map<String, dynamic>>[];
        baseProfile['availableSeats'] = 4;
        baseProfile['occupiedSeats'] = 0;
        baseProfile['isPubliclyVisible'] = true;
      }
      await indexRef.set(baseProfile, SetOptions(merge: true));
    } catch (_) {}

    try {
      await _firestore
          .collection('intercity_vehicles')
          .doc(user.uid)
          .set(baseProfile, SetOptions(merge: true));
    } catch (_) {}
  }
}
