import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:hive_flutter/hive_flutter.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';
import '../screens/driver/driver_trip_chat_screen.dart';
import 'auth_service.dart';
import 'sound_service.dart';

/// Manejador de notificaciones FCM cuando la aplicación está en segundo plano o completamente cerrada
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  debugPrint('[FCM Background] Notificación recibida con la app en segundo plano o cerrada: ${message.messageId}');

  // Si no trae bloque de notificación del sistema pero sí payload de datos, lo mostramos manualmente
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title']?.toString() ?? 'Mijano Drive';
    final body = message.data['body']?.toString() ?? message.data['message']?.toString() ?? '';
    if (title.isNotEmpty || body.isNotEmpty) {
      await NotificationService.showGeneralCampaignNotification(
        title: title,
        body: body,
      );
    }
  }
}

class NotificationService {
  // LLAVE GLOBAL DECLARADA AQUÍ PARA EVITAR ERRORES DE REFERENCIA
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Inicializa el servicio de notificaciones locales y FCM
  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _handleNotificationClick(response.payload!);
        }
      },
    );

    // Canal de ALTA IMPORTANCIA para solicitudes de viaje (Heads-up / Banner)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'trip_alerts_channel',
      'Alertas de Viaje',
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

    // Canal V2 para Campañas Masivas y Alertas (Garantiza Banner flotante de alta prioridad)
    const AndroidNotificationChannel channelV2 = AndroidNotificationChannel(
      'trip_alerts_channel_v2',
      'Alertas y Campañas Masivas',
      description: 'Notificaciones flotantes de anuncios, campañas y alertas de viaje',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('melodia_notificacion'),
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channelV2);

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

    // Configuración de Firebase Cloud Messaging (FCM)
    try {
      final messaging = FirebaseMessaging.instance;

      // Presentación en primer plano
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Manejar mensajes recibidos en primer plano
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Mensaje recibido en primer plano: ${message.messageId}');
        final title = message.notification?.title ?? message.data['title']?.toString() ?? 'Mijano Drive';
        final body = message.notification?.body ?? message.data['body']?.toString() ?? message.data['message']?.toString() ?? '';
        if (title.isNotEmpty || body.isNotEmpty) {
          showGeneralCampaignNotification(title: title, body: body);
        }
      });

      // Manejar clic cuando la notificación abre la app desde segundo plano
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM OpenedApp] Notificación abierta por el usuario');
        final payload = message.data['payload']?.toString() ?? 'general_campaign';
        _handleNotificationClick(payload);
      });

      // Si la app estaba terminada y se abrió al pulsar una notificación FCM
      final RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final payload = initialMessage.data['payload']?.toString() ?? 'general_campaign';
        Future.delayed(const Duration(milliseconds: 700), () {
          _handleNotificationClick(payload);
        });
      }

      // Escuchar cambios de token FCM
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
            'fcmToken': newToken,
            'fcmTokens': FieldValue.arrayUnion([newToken]),
            'lastFcmUpdate': FieldValue.serverTimestamp(),
          }).catchError((_) {});
        }
      });

      // Sincronizar token inicial y tópicos
      unawaited(syncUserFcm());
    } catch (e) {
      debugPrint('[FCM Init] Error configurando Firebase Messaging: $e');
    }

    // Si la app estaba cerrada y se abrió al pulsar una notificación local
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

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );
    } catch (e) {
      debugPrint('[FCM] Error solicitando permisos: $e');
    }
  }

  /// Sincroniza el FCM Token del dispositivo en Firestore y suscribe al usuario a los tópicos según su rol
  static Future<void> syncUserFcm([User? user]) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      final currentUser = user ?? AuthService.instance.currentUser;

      if (token != null && token.isNotEmpty) {
        debugPrint('[FCM] Token del dispositivo obtenido: $token');
        if (currentUser != null) {
          await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
            'fcmToken': token,
            'fcmTokens': FieldValue.arrayUnion([token]),
            'lastFcmUpdate': FieldValue.serverTimestamp(),
          }).catchError((_) {});
        }
      }

      // 1. Tópico general para todos los dispositivos
      await messaging.subscribeToTopic('all');

      // 2. Tópicos según el rol y tipo de vehículo
      if (currentUser != null) {
        final isStaffOrAdmin = currentUser.role == UserRole.admin ||
            currentUser.role == UserRole.operator ||
            currentUser.role == UserRole.support ||
            currentUser.role == UserRole.control;

        if (isStaffOrAdmin) {
          // El administrador se suscribe a todos los tópicos para poder recibir cualquier notificación de prueba
          await messaging.subscribeToTopic('passengers');
          await messaging.subscribeToTopic('drivers_all');
          await messaging.subscribeToTopic('drivers_mototaxi');
          await messaging.subscribeToTopic('drivers_auto');
          debugPrint('[FCM] Administrador suscrito a todos los tópicos');
        } else if (currentUser.role == UserRole.passenger) {
          await messaging.subscribeToTopic('passengers');
          await messaging.unsubscribeFromTopic('drivers_all');
          await messaging.unsubscribeFromTopic('drivers_mototaxi');
          await messaging.unsubscribeFromTopic('drivers_auto');
          debugPrint('[FCM] Suscrito a tópico: passengers');
        } else if (currentUser.role == UserRole.driver) {
          await messaging.subscribeToTopic('drivers_all');
          await messaging.unsubscribeFromTopic('passengers');

          final vehicle = (currentUser.vehicleType ?? '').toLowerCase();
          if (vehicle.contains('moto')) {
            await messaging.subscribeToTopic('drivers_mototaxi');
            await messaging.unsubscribeFromTopic('drivers_auto');
            debugPrint('[FCM] Suscrito a tópico: drivers_mototaxi');
          } else if (vehicle.contains('auto') || vehicle.contains('carro')) {
            await messaging.subscribeToTopic('drivers_auto');
            await messaging.unsubscribeFromTopic('drivers_mototaxi');
            debugPrint('[FCM] Suscrito a tópico: drivers_auto');
          } else {
            debugPrint('[FCM] Suscrito a tópico: drivers_all');
          }
        }
      }
    } catch (e) {
      debugPrint('[FCM] Error en syncUserFcm: $e');
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
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trip_alerts_channel_v2', // Usa el canal v2 con Importance.max
      'Alertas y Campañas Masivas',
      channelDescription: 'Notificaciones flotantes del sistema y anuncios',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      color: Color(0xFFF9D408),
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('melodia_notificacion'),
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
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
        debugPrint('[PushListener] Recibido snapshot con ${snapshot.docChanges.length} cambios, total ${snapshot.docs.length} docs');
        for (final doc in snapshot.docs) {
          final campaignId = doc.id;
          if (_seenCampaignIds.contains(campaignId)) continue;

          final data = doc.data();
          final status = (data['status'] ?? '').toString().toLowerCase();

          // Ignorar campañas creadas hace más de 24 horas para evitar spam antiguo
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          if (createdAt != null) {
            final age = DateTime.now().difference(createdAt);
            if (age.inHours > 24) {
              _seenCampaignIds.add(campaignId);
              continue;
            }
          }

          // Solo procesar si está activa, enviándose, enviada o sin status explícito
          if (status.isNotEmpty && status != 'sending' && status != 'sent' && status != 'active') {
            continue;
          }

          // Verificar si aplica al usuario actual
          final audience = (data['audience'] ?? 'ALL').toString().toUpperCase();
          final targetVehicle = (data['targetVehicleType'] ?? 'ALL').toString().toUpperCase();

          final currentUser = AuthService.instance.currentUser;
          final userRole = currentUser?.role;

          final isAdminOrStaff = userRole == UserRole.admin ||
              userRole == UserRole.operator ||
              userRole == UserRole.support ||
              userRole == UserRole.control;

          bool matches = false;

          if (isAdminOrStaff) {
            // El administrador o personal de control siempre recibe las notificaciones para supervisión/pruebas
            matches = true;
          } else if (audience == 'ALL' || audience == 'TODOS') {
            matches = true;
          } else if (audience == 'PASSENGER' || audience == 'PASAJERO' || audience == 'PASAJEROS') {
            if (userRole == null || userRole == UserRole.passenger) {
              matches = true;
            }
          } else if (audience == 'DRIVER' || audience == 'CONDUCTOR' || audience == 'CONDUCTORES') {
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

            debugPrint('[PushListener] Disparando notificación masiva: $title - $body');
            await showGeneralCampaignNotification(title: title, body: body);
          }
        }
      }, onError: (e) {
        debugPrint('[PushListener] Error en escucha de push_campaigns: $e');
      });
    } catch (e) {
      debugPrint('[PushListener] Error iniciando escucha de push campaigns: $e');
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