import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Servicio para el envío de notificaciones push a través de Firebase Cloud Messaging (FCM).
/// Soporta FCM HTTP v1 con Google Service Account (OAuth 2.0) y FCM Legacy con Server Key.
class FcmSenderService {
  static final FcmSenderService instance = FcmSenderService._internal();
  FcmSenderService._internal();

  String? _cachedAccessToken;
  DateTime? _tokenExpiration;

  /// Obtiene las credenciales FCM guardadas en Firestore (`app_settings/fcm_credentials`)
  Future<Map<String, dynamic>?> getCredentials() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('fcm_credentials')
          .get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('[FcmSender] Error al leer credenciales: $e');
    }
    return null;
  }

  /// Guarda las credenciales de Firebase Service Account en Firestore
  Future<bool> saveCredentials({
    required String projectId,
    required String clientEmail,
    required String privateKey,
    String? serverKey,
  }) async {
    try {
      // Normalizar private key si viene con escapes literales '\n'
      String cleanKey = privateKey.trim();
      if (cleanKey.contains(r'\n')) {
        cleanKey = cleanKey.replaceAll(r'\n', '\n');
      }

      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('fcm_credentials')
          .set({
        'projectId': projectId.trim(),
        'clientEmail': clientEmail.trim(),
        'privateKey': cleanKey,
        'serverKey': serverKey?.trim() ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _cachedAccessToken = null;
      _tokenExpiration = null;
      return true;
    } catch (e) {
      debugPrint('[FcmSender] Error al guardar credenciales: $e');
      return false;
    }
  }

  /// Guarda credenciales directamente pegando el JSON del Service Account
  Future<(bool, String)> saveCredentialsFromJson(String rawJson) async {
    try {
      final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
      final projectId = parsed['project_id']?.toString() ?? '';
      final clientEmail = parsed['client_email']?.toString() ?? '';
      final privateKey = parsed['private_key']?.toString() ?? '';

      if (projectId.isEmpty || clientEmail.isEmpty || privateKey.isEmpty) {
        return (false, 'El JSON no contiene project_id, client_email o private_key válidos.');
      }

      final ok = await saveCredentials(
        projectId: projectId,
        clientEmail: clientEmail,
        privateKey: privateKey,
      );

      if (ok) {
        return (true, '¡Credenciales FCM configuradas correctamente!');
      } else {
        return (false, 'Error guardando en Firestore.');
      }
    } catch (e) {
      return (false, 'Formato JSON inválido: $e');
    }
  }

  /// Genera o reutiliza un Access Token OAuth 2.0 válido para FCM v1
  Future<String?> getOAuth2AccessToken({Map<String, dynamic>? creds}) async {
    if (_cachedAccessToken != null &&
        _tokenExpiration != null &&
        DateTime.now().isBefore(_tokenExpiration!)) {
      return _cachedAccessToken;
    }

    final credentials = creds ?? await getCredentials();
    if (credentials == null) return null;

    final clientEmail = credentials['clientEmail']?.toString() ?? '';
    final privateKeyPem = credentials['privateKey']?.toString() ?? '';

    if (clientEmail.isEmpty || privateKeyPem.isEmpty) return null;

    try {
      final now = DateTime.now().toUtc();
      final nowSeconds = (now.millisecondsSinceEpoch / 1000).round();
      final expSeconds = nowSeconds + 3600;

      final jwt = JWT(
        {
          'iss': clientEmail,
          'sub': clientEmail,
          'aud': 'https://oauth2.googleapis.com/token',
          'scope': 'https://www.googleapis.com/auth/firebase.messaging',
          'iat': nowSeconds,
          'exp': expSeconds,
        },
      );

      final rsaKey = RSAPrivateKey(privateKeyPem);
      final signedJwt = jwt.sign(rsaKey, algorithm: JWTAlgorithm.RS256);

      final tokenResponse = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': signedJwt,
        },
      );

      if (tokenResponse.statusCode == 200) {
        final data = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
        final accessToken = data['access_token']?.toString();
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;

        _cachedAccessToken = accessToken;
        // Guardar con 5 minutos de margen antes de que expire
        _tokenExpiration = DateTime.now().add(Duration(seconds: expiresIn - 300));
        debugPrint('[FcmSender] Token OAuth 2.0 obtenido exitosamente');
        return accessToken;
      } else {
        debugPrint('[FcmSender] Error en OAuth token (${tokenResponse.statusCode}): ${tokenResponse.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[FcmSender] Excepción generando token OAuth: $e');
      return null;
    }
  }

  /// Mapea la audiencia y tipo de vehículo al nombre del tópico FCM
  String getTopicForAudience({
    required String audience,
    required String targetVehicleType,
  }) {
    final aud = audience.toUpperCase();
    final veh = targetVehicleType.toUpperCase();

    if (aud == 'ALL' || aud == 'TODOS') {
      return 'all';
    } else if (aud == 'PASSENGER' || aud == 'PASAJERO' || aud == 'PASAJEROS') {
      return 'passengers';
    } else if (aud == 'DRIVER' || aud == 'CONDUCTOR' || aud == 'CONDUCTORES') {
      if (veh == 'MOTOTAXI') {
        return 'drivers_mototaxi';
      } else if (veh == 'AUTO' || veh == 'CARRO') {
        return 'drivers_auto';
      } else {
        return 'drivers_all';
      }
    }
    return 'all';
  }

  /// Envía la notificación push a través de FCM HTTP v1 (o fallback a Legacy)
  /// para que llegue a los dispositivos con la app cerrada o en segundo plano.
  Future<(bool, String)> sendCampaignPush({
    required String title,
    required String message,
    required String audience,
    required String targetVehicleType,
    Map<String, dynamic>? extraData,
  }) async {
    final creds = await getCredentials();
    if (creds == null) {
      return (false, 'No se han configurado las credenciales FCM en el Panel Admin.');
    }

    final projectId = creds['projectId']?.toString() ?? 'mijanodrive-peru';
    final topic = getTopicForAudience(
      audience: audience,
      targetVehicleType: targetVehicleType,
    );

    // 1. Intentar envío oficial con FCM HTTP v1
    final accessToken = await getOAuth2AccessToken(creds: creds);
    if (accessToken != null) {
      try {
        final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

        final body = {
          'message': {
            'topic': topic,
            'notification': {
              'title': title,
              'body': message,
            },
            'android': {
              'priority': 'HIGH',
              'notification': {
                'channel_id': 'trip_alerts_channel_v2',
                'sound': 'melodia_notificacion',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'default_vibrate_timings': true,
                'notification_priority': 'PRIORITY_MAX',
              },
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'title': title,
              'body': message,
              'audience': audience,
              'targetVehicleType': targetVehicleType,
              'type': 'general_campaign',
              if (extraData != null)
                ...extraData.map((k, v) => MapEntry(k, v.toString())),
            },
          },
        };

        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json; UTF-8',
          },
          body: jsonEncode(body),
        );

        if (response.statusCode == 200) {
          debugPrint('[FcmSender] Notificación enviada con éxito al tópico: $topic');
          return (true, 'Push FCM v1 entregado con éxito al tópico: $topic');
        } else {
          debugPrint('[FcmSender] Error en FCM v1 (${response.statusCode}): ${response.body}');
          return (false, 'FCM v1 devolvió error ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FcmSender] Excepción en envío FCM v1: $e');
      }
    }

    // 2. Fallback a FCM Legacy si existe serverKey configurada
    final serverKey = creds['serverKey']?.toString() ?? '';
    if (serverKey.isNotEmpty) {
      try {
        final legacyUrl = Uri.parse('https://fcm.googleapis.com/fcm/send');
        final legacyBody = {
          'to': '/topics/$topic',
          'priority': 'high',
          'notification': {
            'title': title,
            'body': message,
            'sound': 'melodia_notificacion',
            'android_channel_id': 'trip_alerts_channel_v2',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'title': title,
            'body': message,
            'audience': audience,
            'targetVehicleType': targetVehicleType,
            'type': 'general_campaign',
          },
        };

        final legacyRes = await http.post(
          legacyUrl,
          headers: {
            'Authorization': 'key=$serverKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(legacyBody),
        );

        if (legacyRes.statusCode == 200) {
          return (true, 'Push Legacy entregado con éxito al tópico: $topic');
        }
      } catch (e) {
        debugPrint('[FcmSender] Excepción en FCM Legacy: $e');
      }
    }

    return (false, 'No se pudo enviar vía FCM. Verifica la configuración de Service Account.');
  }

  /// Verifica si el servicio está configurado y listo para enviar notificaciones en segundo plano
  Future<bool> isConfigured() async {
    final creds = await getCredentials();
    if (creds == null) return false;
    final email = creds['clientEmail']?.toString() ?? '';
    final key = creds['privateKey']?.toString() ?? '';
    final serverKey = creds['serverKey']?.toString() ?? '';
    return (email.isNotEmpty && key.isNotEmpty) || serverKey.isNotEmpty;
  }
}
