import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../screens/driver/driver_trip_chat_screen.dart';
import 'auth_service.dart';
import 'sound_service.dart';

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
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Manejar el clic en la notificación
        if (response.payload != null) {
          _handleNotificationClick(response.payload!);
        }
      },
    );

    // Canal de ALTA IMPORTANCIA para que flote sobre la pantalla (Heads-up / Banner)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'trip_alerts_channel', // ID del canal
      'Alertas de Viaje', // Nombre visible para el usuario
      description: 'Notificaciones flotantes de solicitudes y estados de viaje',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('melodia_notificacion'),
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Canal para MENSAJES DE CHAT en viaje activo
    const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'trip_chat_channel',
      'Mensajes de Chat',
      description: 'Notificaciones de mensajes de chat en viajes activos',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('melodia_notificacion'),
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(chatChannel);

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
      sound: RawResourceAndroidNotificationSound('melodia_notificacion'),
      fullScreenIntent: true, // Forzar banner emergente flotante arriba
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
      payload: 'general_campaign',
    );

    // Reproducir melodía configurada de notificación
    unawaited(SoundService.instance.playNotificationSound());
  }

  // ===========================================================================
  // ESCUCHADOR EN TIEMPO REAL DE CAMPAÑAS PUSH MASIVAS
  // ===========================================================================
  static StreamSubscription? _campaignsSubscription;
  static final Set<String> _seenCampaignIds = {};

  static Future<void> startMassCampaignListener() async {
    _campaignsSubscription?.cancel();

    try {
      // Cargar IDs ya vistos desde Hive
      Box? box;
      try {
        if (Hive.isBoxOpen('notifications_cache')) {
          box = Hive.box('notifications_cache');
        } else {
          box = await Hive.openBox('notifications_cache');
        }
        final List<dynamic>? stored = box.get('seen_campaigns');
        if (stored != null) {
          _seenCampaignIds.addAll(stored.map((e) => e.toString()));
        }
      } catch (_) {}

      // Escuchar campañas en tiempo real en Firestore
      _campaignsSubscription = FirebaseFirestore.instance
          .collection('push_campaigns')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots()
          .listen((snapshot) async {
        for (final doc in snapshot.docs) {
          final campaignId = doc.id;
          if (_seenCampaignIds.contains(campaignId)) continue;

          final data = doc.data();
          final status = (data['status'] ?? '').toString().toLowerCase();

          // Ignorar campañas creadas hace más de 2 horas para evitar spam histórico al iniciar
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          if (createdAt != null) {
            final age = DateTime.now().difference(createdAt);
            if (age.inHours > 2) {
              _seenCampaignIds.add(campaignId);
              continue;
            }
          }

          // Solo procesar si está activa o enviándose
          if (status != 'sending' && status != 'sent' && status != 'active') {
            continue;
          }

          // Verificar si aplica al usuario actual
          final audience = (data['audience'] ?? 'ALL').toString().toUpperCase();
          final targetVehicle = (data['targetVehicleType'] ?? 'ALL').toString().toUpperCase();

          final currentUser = AuthService.instance.currentUser;
          final userRole = currentUser?.role;

          bool matches = false;

          if (audience == 'ALL') {
            matches = true;
          } else if (audience == 'PASSENGER' || audience == 'PASAJERO') {
            if (userRole == UserRole.passenger || currentUser == null) {
              matches = true;
            }
          } else if (audience == 'DRIVER' || audience == 'CONDUCTOR') {
            if (userRole == UserRole.driver) {
              // Validar tipo de vehículo si es conductor (Auto vs Mototaxi)
              if (targetVehicle == 'ALL') {
                matches = true;
              } else {
                final userVehicle = (currentUser?.vehicleType ?? '').toUpperCase();
                if (targetVehicle == 'MOTOTAXI' && userVehicle.contains('MOTO')) {
                  matches = true;
                } else if ((targetVehicle == 'AUTO' || targetVehicle == 'CARRO') &&
                    (userVehicle.contains('AUTO') || userVehicle.contains('CARRO'))) {
                  matches = true;
                }
              }
            }
          }

          if (matches) {
            _seenCampaignIds.add(campaignId);
            try {
              if (box != null && box.isOpen) {
                await box.put('seen_campaigns', _seenCampaignIds.toList());
              }
            } catch (_) {}

            final title = data['title']?.toString() ?? 'Mijano Drive';
            final body = data['message']?.toString() ?? data['body']?.toString() ?? '';

            await showGeneralCampaignNotification(title: title, body: body);
          }
        }
      }, onError: (e) {
        debugPrint('Aviso: Escucha de push_campaigns: $e');
      });
    } catch (e) {
      debugPrint('Error iniciando escucha de push campaigns: $e');
    }
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
      sound: RawResourceAndroidNotificationSound('melodia_notificacion'),
      fullScreenIntent: true, // Permite mostrar sobre la pantalla de bloqueo
      styleInformation: BigTextStyleInformation(''), // Permite textos de varias líneas
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );

    // Reproducir melodía configurada de notificación
    unawaited(SoundService.instance.playNotificationSound());
  }

  static void _handleNotificationClick(String payload) {
    // El payload viene estructurado con el tipo y el ID
    final parts = payload.split(':');
    if (parts.isEmpty) return;

    final type = parts[0]; 

    if (type == 'trip_request' || type == 'plan_approved' || type == 'general_campaign') {
      final currentState = navigatorKey.currentState;
      if (currentState != null) {
        bool isOnDriver = false;
        currentState.popUntil((r) {
          if (r.settings.name == '/driver') {
            isOnDriver = true;
            return true;
          }
          if (r.isFirst) {
            return true;
          }
          return false;
        });
        if (!isOnDriver) {
          currentState.pushNamed('/driver');
        }
      }
    } else if (type == 'trip_accepted') {
      final tripId = parts.length > 1 ? parts[1] : '';
      navigatorKey.currentState?.pushNamed(
        '/active-trip',
        arguments: {'tripId': tripId},
      );
    } else if (type == 'trip_searching') {
      navigatorKey.currentState?.pushNamed('/home');
    } else if (type == 'trip_chat') {
      final tripId = parts.length > 1 ? parts[1] : '';
      final senderName = parts.length > 2 ? parts[2] : 'Chat';
      final conversationTitle = parts.length > 3 ? parts[3] : senderName;

      final current = AuthService.instance.currentUser;
      final currentUserId = current?.uid ?? fb.FirebaseAuth.instance.currentUser?.uid ?? '';
      final currentUserName = current?.name ?? 'Usuario';

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => DriverTripChatScreen(
            tripId: tripId,
            senderId: currentUserId,
            senderName: currentUserName,
            conversationTitle: conversationTitle,
          ),
        ),
      );
    }
  }

  /// Notificación para Nuevo Mensaje de Chat en viaje activo
  static Future<void> showChatMessageNotification({
    required String tripId,
    required String senderName,
    required String messageText,
    required String conversationTitle,
  }) async {
    final title = '💬 Mensaje de $senderName';
    final body = messageText;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trip_chat_channel',
      'Mensajes de Chat',
      channelDescription: 'Notificaciones de mensajes de chat en viajes activos',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      color: Color(0xFFF9D408),
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      'chat_$tripId'.hashCode,
      title,
      body,
      platformDetails,
      payload: 'trip_chat:$tripId:$senderName:$conversationTitle',
    );
  }
}