import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DocumentService {
  static final DocumentService instance = DocumentService._internal();
  DocumentService._internal();

  Future<void> uploadDriverDocument({
    required String documentKey, 
    required File imageFile,     
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('drivers')
          .child(uid)
          .child('$documentKey.jpg');

      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);
      final TaskSnapshot snapshot = await uploadTask;

      // 3. Obtener la URL pública de descarga
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // 4. Guardar esa URL dentro del mapa 'documents' en Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'documents.$documentKey': downloadUrl,
        'documents.${documentKey}Status': 'pending',
      });

    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadPassengerDniPhoto({
    required String uid,
    required String side, // 'front' o 'back'
    required File imageFile,
  }) async {
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'uploadedBy': uid, 'side': side},
    );

    // 1. Intentar en la ruta oficial /passengers/
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('passengers')
          .child(uid)
          .child('dni_$side.jpg');

      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      // 2. Si falla por reglas de Storage en Firebase, reintentar en /drivers/ (que ya tiene permisos activos)
      try {
        final fallbackRef = FirebaseStorage.instance
            .ref()
            .child('drivers')
            .child(uid)
            .child('dni_passenger_$side.jpg');

        final UploadTask fallbackTask = fallbackRef.putFile(imageFile, metadata);
        final TaskSnapshot snapshot = await fallbackTask;
        return await snapshot.ref.getDownloadURL();
      } catch (_) {
        // 3. Fallback a /profile_images/
        try {
          final profileRef = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child(uid)
              .child('dni_$side.jpg');

          final UploadTask profileTask = profileRef.putFile(imageFile, metadata);
          final TaskSnapshot snapshot = await profileTask;
          return await snapshot.ref.getDownloadURL();
        } catch (_) {
          rethrow;
        }
      }
    }
  }

  Future<String> uploadAdImage(String adId, List<int> imageBytes) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('ads/$adId.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      
      final uploadTask = storageRef.putData(
        Uint8List.fromList(imageBytes),
        metadata,
      );
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadReceipt(String uid, List<int> imageBytes) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance.ref().child('plan_receipts/$uid/$timestamp.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      
      final uploadTask = storageRef.putData(
        Uint8List.fromList(imageBytes),
        metadata,
      );
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, String>> uploadPaymentQr(Uint8List imageBytes, String extension) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'settings/payment_qr/qr_$timestamp.$extension';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: extension.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg',
      );

      final uploadTask = storageRef.putData(
        imageBytes,
        metadata,
      );
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      return {
        'url': url,
        'storagePath': storagePath,
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteStorageFile(String storagePath) async {
    if (storagePath.trim().isEmpty) return;
    try {
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.delete();
    } catch (_) {
      // Ignorar si el archivo no existe
    }
  }
}