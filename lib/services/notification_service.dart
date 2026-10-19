import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  // LLAVE GLOBAL DECLARADA AQUÍ PARA EVITAR ERRORES DE REFERENCIA
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Inicializa el servicio de notificaciones y los canales de alta prioridad
  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Manejar el clic en la notificación
        if (response.payload != null) {
          _handleNotificationClick(response.payload!);
        }
      },
    );

    // Canal de ALTA IMPORTANCIA para que flote sobre la pantalla (Heads-up / Banner)
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      'trip_alerts_channel', // ID del canal
      'Alertas de Viaje', // Nombre visible para el usuario
      description: 'Notificaciones flotantes de solicitudes y estados de viaje',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Si la app estaba cerrada y se abrió al pulsar la notificación
    final NotificationAppLaunchDetails? launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final payload = launchDetails.notificationResponse?.payload;
      if (payload != null) {
        Future.delayed(const Duration(milliseconds: 600), () {
          _handleNotificationClick(payload);
        });
      }
    }
  }

  /// Solicitud de permisos para Android 13+ / iOS
  static Future<void> requestPermissions() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  // ===========================================================================
  // GUARDAR EN FIRESTORE (MÉTODO PRIVADO)
  // ===========================================================================

  static Future<void> _saveToFirestore({
    required String title,
    required String body,
    required String tripId,
    required String type,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'tripId': tripId,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error al guardar en Firestore: $e');
    }
  }

  // ===========================================================================
  // NOTIFICACIONES ESPECÍFICAS DEL FLUJO DE VIAJE Y PLANES
  // ===========================================================================

  /// 1. Notificación para el Conductor: Nueva solicitud de viaje en la zona
  static Future<void> showNewTripRequestToDriver({
    required String tripId,
    required String passengerName,
    required double price,
    required String pickupAddress,
  }) async {
    final title = '¡Nueva solicitud de viaje! 🛺';
    final body = 'Pasajero: $passengerName · S/ ${price.toStringAsFixed(2)}\nRecogida: $pickupAddress';

    await _showNotification(
      id: tripId.hashCode,
      title: title,
      body: body,
      payload: 'trip_request:$tripId',
    );

    await _saveToFirestore(
      title: title,
      body: body,
      tripId: tripId,
      type: 'trip_request',
    );
  }

  /// 2. Notificación para el Pasajero: Un conductor aceptó la carrera
  static Future<void> showTripAcceptedToPassenger({
    required String tripId,
    required String driverName,
    required String vehicleInfo,
    required String pickupAddress,
  }) async {
    final title = '¡Solicitud Aceptada! 🎉';
    final body = 'Conductor: $driverName · MotoTaxi: $vehicleInfo\nRecogida: $pickupAddress';

    await _showNotification(
      id: tripId.hashCode,
      title: title,
      body: body,
      payload: 'trip_accepted:$tripId',
    );

    await _saveToFirestore(
      title: title,
      body: body,
      tripId: tripId,
      type: 'trip_accepted',
    );
  }

  /// 3. Notificación para el Pasajero: Buscando conductores
  static Future<void> showSearchingDriverToPassenger({
    required String tripId,
    required String destinationAddress,
  }) async {
    final title = 'Buscando conductores cercanos... 🔎';
    final body = 'Tu solicitud hacia $destinationAddress ha sido publicada.';

    await _showNotification(
      id: tripId.hashCode,
      title: title,
      body: body,
      payload: 'trip_searching:$tripId',
    );

    await _saveToFirestore(
      title: title,
      body: body,
      tripId: tripId,
      type: 'trip_searching',
    );
  }

  /// 4. Notificación flotante para el Conductor: Plan Aprobado
  static Future<void> showPlanApprovedNotification({
    required String planName,
  }) async {
    const title = '¡Plan Aprobado! 🎉';
    final body = 'Tu solicitud para el plan $planName ha sido aprobada con éxito. Ya puedes activarte para recibir viajes.';

    await _showNotification(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      payload: 'plan_approved',
    );
  }

  /// 5. Notificación general flotante para campañas y anuncios masivos
  static Future<void> showGeneralCampaignNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trip_alerts_channel', // Usa el canal con Importance.max
      'Alertas de Viaje',
      channelDescription: 'Notificaciones flotantes del sistema',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFF9D408),
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true, // Forzar banner emergente flotante arriba
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: 'general_campaign',
    );
  }

  // ===========================================================================
  // MÉTODOS INTERNOS Y MANEJO DE NAVEGACIÓN
  // ===========================================================================

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trip_alerts_channel',
      'Alertas de Viaje',
      channelDescription: 'Notificaciones flotantes de solicitudes y estados de viaje',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFF9D408), // Color amarillo de Mijano Drive
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true, // Permite mostrar sobre la pantalla de bloqueo
      styleInformation: BigTextStyleInformation(''), // Permite textos de varias líneas
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  static void _handleNotificationClick(String payload) {
    // El payload viene estructurado con el tipo y el ID
    final parts = payload.split(':');
    if (parts.isEmpty) return;

    final type = parts[0]; 

    if (type == 'trip_request') {
      navigatorKey.currentState?.pushNamed('/driver');
    } else if (type == 'trip_accepted') {
      final tripId = parts.length > 1 ? parts[1] : '';
      navigatorKey.currentState?.pushNamed(
        '/active-trip',
        arguments: {'tripId': tripId},
      );
    } else if (type == 'trip_searching') {
      navigatorKey.currentState?.pushNamed('/home');
    } else if (type == 'plan_approved') {
      // Llevar al panel del conductor al pulsar la notificación de plan aprobado
      navigatorKey.currentState?.pushNamed('/driver');
    } else if (type == 'general_campaign') {
      navigatorKey.currentState?.pushNamed('/driver');
    }
  }
}