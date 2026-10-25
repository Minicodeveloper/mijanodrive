import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/trip_model.dart';
import '../models/driver_model.dart';
import '../models/driver_plan_model.dart';
import '../models/plan_model.dart';
import '../models/wallet_model.dart';
import '../models/tariff_model.dart';
import '../utils/role_helper.dart';
import '../admin/utils/driver_docs.dart';
import 'auth_service.dart';
import 'document_service.dart';
import 'location_service.dart';
import '../config/app_config.dart';
import '../models/plan_tier.dart';

// ============================================================================
// CONTRATO DE DATOS: PLANES Y SOLICITUDES
// plan_requests: driverId, driverName, driverPhone, planId, planName, amount,
//                days, priority, receiptUrl, notes, status ('pending'|'approved'|'rejected'),
//                rejectReason, createdAt, reviewedBy, reviewedAt.
// driver_plans:  planId, planName, priority, startsAt, expiresAt, status ('active'|'expired'),
//                activatedBy, updatedAt. (ID del documento = driverId)
// drivers:       planPaymentStatus ('pending'|'active'|'rejected'), activePlanId, planExpiresAt
// ============================================================================

class FirestoreService {
  static final FirestoreService instance = FirestoreService._();
  FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- Usuarios ----
  Future<void> saveUser(User user) => _db
      .collection('users')
      .doc(user.uid)
      .set(user.toMap(), SetOptions(merge: true));

  Future<User?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return User.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  Future<User?> getUserByPhone(String phone) async {
    try {
      final q = await _db
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      return User.fromFirestore(q.docs.first);
    } catch (_) {
      return null;
    }
  }

  // ---- DNI Unicidad ----
  Future<bool> isDniTaken(String dni) async {
    try {
      final q = await _db
          .collection('users')
          .where('dni', isEqualTo: dni.trim())
          .limit(1)
          .get();
      return q.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---- Conductores ----
  Future<void> saveDriver(Driver driver) => _db
      .collection('drivers')
      .doc(driver.uid)
      .set(driver.toMap(), SetOptions(merge: true));

  Future<Driver?> getDriver(String uid) async {
    try {
      final doc = await _db.collection('drivers').doc(uid).get();
      if (!doc.exists) return null;
      return Driver.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  Future<void> setDriverAvailability(String uid, bool available) => _db
      .collection('drivers')
      .doc(uid)
      .set({'isAvailable': available}, SetOptions(merge: true));

  Future<void> updateDriverLocation(String uid, double lat, double lng) =>
      _db.collection('drivers').doc(uid).set({
        'currentLatitude': lat,
        'currentLongitude': lng,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  // ---- Viajes ----
  Future<Map<String, dynamic>> _buildDispatchData(GeoPoint origin) async {
    double maxDispatchRadiusKm = AppConfig.kMaxDispatchRadiusKm;
    try {
      final pricing = await getPricingSettings();
      if (pricing.maxOfferRadiusKm > 0) {
        maxDispatchRadiusKm = pricing.maxOfferRadiusKm;
      }
    } catch (_) {}

    final driversSnapshot = await _db.collection('drivers')
        .where('isAvailable', isEqualTo: true)
        .where('planPaymentStatus', isEqualTo: 'active')
        .get();
        
    final List<DispatchCandidate> candidates = [];
    final Map<String, PlanTier> candidateTiers = {};

    for (var doc in driversSnapshot.docs) {
      final data = doc.data();
      
      final expiresAt = (data['planExpiresAt'] as Timestamp?)?.toDate();
      final hasNotExpired = expiresAt?.isAfter(DateTime.now()) ?? false;

      if (hasNotExpired) {
        final double? lat = (data['currentLatitude'] as num?)?.toDouble();
        final double? lng = (data['currentLongitude'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          final distance = LocationService.instance.distanceKm(
            lat,
            lng,
            origin.latitude,
            origin.longitude,
          );

          if (distance <= maxDispatchRadiusKm) {
            final tier = PlanTier.resolve(data);
            candidates.add(DispatchCandidate(
              id: doc.id,
              distanceKm: distance,
              tier: tier,
            ));
            candidateTiers[doc.id] = tier;
          }
        }
      }
    }

    final dispatchQueue = buildDispatchOrder(candidates);
    
    final currentDispatchDriverId = dispatchQueue.isNotEmpty ? dispatchQueue.first : null;
    String? currentDispatchPlan;
    if (currentDispatchDriverId != null) {
       currentDispatchPlan = candidateTiers[currentDispatchDriverId]?.key;
    }

    return {
      'dispatchQueue': dispatchQueue,
      'dispatchIndex': 0,
      'currentDispatchDriverId': currentDispatchDriverId,
      'currentDispatchPlan': currentDispatchPlan,
      'dispatchDeadline': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: AppConfig.kDispatchTimeoutSeconds))),
      'rejectedDriverIds': [],
      'dispatchExhausted': dispatchQueue.isEmpty,
    };
  }

  Future<String> createTrip(Trip trip) async {
    final tripData = trip.toMap();
    
    final dispatchData = await _buildDispatchData(trip.origin);
    tripData.addAll(dispatchData);

    // cleanup
    tripData.remove('monthlyQueue');
    tripData.remove('currentMonthlyIndex');
    tripData.remove('currentMonthlyDriverId');
    tripData.remove('monthlyDeadline');
    tripData.remove('rejectedMonthlyDriverIds');

    final ref = await _db.collection('trips').add(tripData);
    return ref.id;
  }

  Future<DocumentReference> createTripWithDispatch(Map<String, dynamic> tripData, {required GeoPoint origin}) async {
    final dispatchData = await _buildDispatchData(origin);
    tripData.addAll(dispatchData);
    return await _db.collection('trips').add(tripData);
  }

  Future<void> _advanceDispatchInTx(Transaction tx, DocumentReference tripRef, Map<String, dynamic> data, int nextIndex) async {
    List<dynamic> queueDyn = data['dispatchQueue'] ?? [];
    if (nextIndex < queueDyn.length) {
      final nextDriverId = queueDyn[nextIndex].toString();
      final nextDriverDoc = await tx.get(_db.collection('drivers').doc(nextDriverId));
      String planKey = 'diario';
      if (nextDriverDoc.exists) {
        final driverData = nextDriverDoc.data();
        planKey = PlanTier.resolve(driverData).key;
      }

      tx.update(tripRef, {
        'dispatchIndex': nextIndex,
        'currentDispatchDriverId': nextDriverId,
        'currentDispatchPlan': planKey,
        'dispatchDeadline': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: AppConfig.kDispatchTimeoutSeconds))),
      });
    } else {
      tx.update(tripRef, {
        'currentDispatchDriverId': null,
        'dispatchExhausted': true,
      });
    }
  }

  Future<void> advanceDispatch(String tripId, {required int expectedIndex}) async {
    final tripRef = _db.collection('trips').doc(tripId);
    
    await _db.runTransaction((tx) async {
      final doc = await tx.get(tripRef);
      if (!doc.exists) return;
      
      final data = doc.data()!;
      if (data['status'] != 'pending') return;
      
      final currentIndex = data['dispatchIndex'] ?? 0;
      if (currentIndex != expectedIndex) return;

      await _advanceDispatchInTx(tx, tripRef, data, currentIndex + 1);
    });
  }

  Future<void> rejectDispatch(String tripId, String driverUid) async {
    final tripRef = _db.collection('trips').doc(tripId);
    
    await _db.runTransaction((tx) async {
      final doc = await tx.get(tripRef);
      if (!doc.exists) return;
      
      final data = doc.data()!;
      if (data['status'] != 'pending') return;
      
      final currentDriverId = data['currentDispatchDriverId'];
      final currentIndex = data['dispatchIndex'] ?? 0;
      
      tx.update(tripRef, {
        'rejectedDriverIds': FieldValue.arrayUnion([driverUid])
      });
      
      if (currentDriverId == driverUid) {
        await _advanceDispatchInTx(tx, tripRef, data, currentIndex + 1);
      }
    });
  }

  Future<void> resetDispatch(String tripId) async {
    final tripRef = _db.collection('trips').doc(tripId);
    final doc = await tripRef.get();
    if (!doc.exists) return;

    final trip = Trip.fromMap(doc.data()!, doc.id);
    final dispatchData = await _buildDispatchData(trip.origin);
    await tripRef.update(dispatchData);
  }

  Future<void> updateTrip(String id, Map<String, dynamic> data) =>
      _db.collection('trips').doc(id).set(data, SetOptions(merge: true));

  Future<void> cancelTrip(String id, {required String cancelledBy, String? reason}) =>
      _db.collection('trips').doc(id).set({
        'status': 'cancelled',
        'cancelledBy': cancelledBy,
        'cancelReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Stream<Trip?> tripStream(String id) => _db
      .collection('trips')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Trip.fromFirestore(doc) : null);

  /// Viajes pendientes en una ciudad (para el conductor).
  Stream<List<Trip>> pendingTrips() {
  return FirebaseFirestore.instance
      .collection('trips')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) => Trip.fromFirestore(doc)).toList();
      });
}

  Stream<List<Trip>> tripsForPassenger(String uid) => _db
      .collection('trips')
      .where('passengerId', isEqualTo: uid)
      .snapshots()
      .map((q) => q.docs.map((d) => Trip.fromFirestore(d)).toList());

  /// Viajes completados por un conductor (para la pantalla de historial).
  Stream<List<Trip>> completedTripsForDriver(String driverId) => _db
      .collection('trips')
      .where('driverId', isEqualTo: driverId)
      .where('status', isEqualTo: 'completed')
      .snapshots()
      .map((q) => q.docs.map((d) => Trip.fromFirestore(d)).toList());

  // ---- Billetera ----
  Future<Wallet> getOrCreateWallet(String uid) async {
    try {
      final doc = await _db.collection('wallets').doc(uid).get();
      if (doc.exists) return Wallet.fromFirestore(doc);
    } catch (_) {}
    final w = Wallet(uid: uid, balance: 0, lastUpdated: DateTime.now());
    try {
      await _db.collection('wallets').doc(uid).set(w.toMap());
    } catch (_) {}
    return w;
  }

  Stream<Wallet?> walletStream(String uid) => _db
      .collection('wallets')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? Wallet.fromFirestore(doc) : null);

  Stream<List<Map<String, dynamic>>> transactions(String uid) => _db
      .collection('transactions')
      .where('walletId', isEqualTo: uid)
      .snapshots()
      .map((q) => q.docs.map((d) => d.data()).toList());

  // ---- Ciudades / tarifas ----
  Future<Map<String, dynamic>?> getCityTariff(String city) async {
    try {
      final q = await _db
          .collection('cities')
          .where('name', isEqualTo: city)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      return q.docs.first.data();
    } catch (_) {
      return null;
    }
  }

  // =====================================================
  //  ADMIN (panel web) — consume la MISMA colección
  // =====================================================

  
  Stream<List<Trip>> allActiveTrips() => _db
      .collection('trips')
      .where('status', whereIn: ['pending', 'accepted', 'arrived', 'active'])
      .snapshots()
      .map((q) => q.docs.map((d) => Trip.fromFirestore(d)).toList());

  Stream<List<Driver>>? _allDriversStream;

  Driver? _mergeDriverData(Map<String, dynamic> uData, Map<String, dynamic> dData, String uid) {
    final role = RoleHelper.normalizeRole(uData['role']);
    if (role != 'driver') return null;

    final merged = <String, dynamic>{
        ...uData,
        'currentLatitude': dData['currentLatitude'],
        'currentLongitude': dData['currentLongitude'],
        'locationUpdatedAt': dData['locationUpdatedAt'],
        'isAvailable': dData['isAvailable'] ?? uData['isAvailable'] ?? false,
    };
    
    try {
      return Driver.fromMap(merged, uid);
    } catch (e) {
      return null;
    }
  }

  
  Stream<List<Driver>> allDrivers() {
    if (_allDriversStream != null) return _allDriversStream!;

    late StreamController<List<Driver>> controller;
    StreamSubscription? usersSub;
    StreamSubscription? driversSub;

    List<Map<String, dynamic>> usersData = [];
    List<Map<String, dynamic>> driversData = [];

    void emit() {
      final driversMap = {for (final d in driversData) d['uid'] ?? d['id']: d};
      final result = <Driver>[];

      for (final u in usersData) {
        final uid = u['uid'] ?? u['id'];
        if (uid == null) continue;
        final dData = driversMap[uid] ?? {};
        final driver = _mergeDriverData(u, dData, uid);
        if (driver != null) {
          result.add(driver);
        }
      }
      controller.add(result);
    }

    controller = StreamController<List<Driver>>.broadcast(
      onListen: () {
        usersSub = _db.collection('users').snapshots().listen((snap) {
          usersData = snap.docs.map((d) => {'uid': d.id, 'id': d.id, ...d.data()}).toList();
          emit();
        });
        driversSub = _db.collection('drivers').snapshots().listen((snap) {
          driversData = snap.docs.map((d) => {'uid': d.id, 'id': d.id, ...d.data()}).toList();
          emit();
        });
      },
      onCancel: () {
        usersSub?.cancel();
        driversSub?.cancel();
        _allDriversStream = null;
      }
    );

    _allDriversStream = controller.stream;
    return _allDriversStream!;
  }

  /// Conductores pendientes de aprobación optimizados para la consola web.
  Stream<List<Driver>> pendingDrivers() => 
      allDrivers().map((drivers) => drivers.where((d) => d.status == 'pending').toList());

  /// Actualiza la cuenta en `users` (login / estado de la cuenta) y, si existe,
  /// en `drivers` (listado del panel), para que ambas colecciones no se
  /// desincronicen. Sirve también para pasajeros: ahí `drivers/{uid}` no existe.
  Future<void> _updateAccountDocs(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
    final driverRef = _db.collection('drivers').doc(uid);
    final snap = await driverRef.get();
    if (snap.exists) await driverRef.update(data);
  }

  Future<void> approveDriver(String uid, bool approved) async {
    if (approved) {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
         final d = Driver.fromMap(doc.data()!, uid);
         if (!DriverDocs.allApproved(d)) {
            throw Exception('No se puede aprobar. Faltan documentos requeridos.');
         }
      }
    }
    return _updateAccountDocs(uid, {
        'isApproved': approved,
        'status': approved ? 'approved' : 'rejected',
      });
  }

  Future<void> updateDriverStatus(
    String uid, {
    bool? isApproved,
    bool? isBlocked,
    bool? isRejected,
  }) {
    final Map<String, dynamic> data = {};
    if (isApproved != null) {
      data['isApproved'] = isApproved;
      data['status'] = isApproved ? 'approved' : 'pending';
    }
    if (isBlocked != null) data['isBlocked'] = isBlocked;
    if (isRejected != null) {
      data['isRejected'] = isRejected;
      if (isRejected) data['status'] = 'rejected';
    }
    return _updateAccountDocs(uid, data);
  }

  Future<void> updateDriverDocumentStatus(String uid, String campoEstado, String nuevoEstado) async {
    final userRef = _db.collection('users').doc(uid);
    final doc = await userRef.get();
    if (!doc.exists) return;
    
    final data = doc.data()!;
    var docs = data['documents'];
    
    Map<String, dynamic> parsedDocs = {};
    if (docs is List) {
       for (var item in docs) {
         if (item is Map) {
            final id = item['id'];
            if (id == 'dni') {
              parsedDocs['docFront'] = item['url'];
              parsedDocs['docFrontStatus'] = item['status'];
            } else if (id == 'license') {
              parsedDocs['licensedDocument'] = item['url'];
              parsedDocs['licensedDocumentStatus'] = item['status'];
            } else if (id == 'soat') {
              parsedDocs['soatPhoto'] = item['url'];
              parsedDocs['soatPhotoStatus'] = item['status'];
            } else {
              parsedDocs[id.toString()] = item['url'];
              parsedDocs['${id}Status'] = item['status'];
            }
         }
       }
    } else if (docs is Map) {
       parsedDocs = Map<String, dynamic>.from(docs);
    }

    parsedDocs[campoEstado] = nuevoEstado;
    await _updateAccountDocs(uid, {'documents': parsedDocs});
  }

  // =====================================================
  //  PERMISOS: cuentas del panel, conductores y pasajeros
  // =====================================================

  
  static const List<String> staffRoles = ['admin', 'superAdmin', 'operator', 'support', 'control'];

  
  Stream<List<Map<String, dynamic>>> staffAccounts() => _db
      .collection('users')
      .where('role', whereIn: staffRoles)
      .snapshots()
      .map((q) => q.docs.map((d) => {'uid': d.id, ...d.data()}).toList());

  
  Stream<Map<String, dynamic>?> userDoc(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? {'uid': d.id, ...?d.data()} : null);

  
  Stream<Driver?> driverStream(String uid) {
    late StreamController<Driver?> controller;
    StreamSubscription? userSub;
    StreamSubscription? driverSub;

    Map<String, dynamic>? uData;
    Map<String, dynamic>? dData;

    void emit() {
      if (uData == null) {
        controller.add(null);
        return;
      }
      final driver = _mergeDriverData(uData!, dData ?? {}, uid);
      controller.add(driver);
    }

    controller = StreamController<Driver?>.broadcast(
      onListen: () {
        userSub = _db.collection('users').doc(uid).snapshots().listen((snap) {
          if (snap.exists) {
            uData = {'uid': snap.id, 'id': snap.id, ...?snap.data()};
          } else {
            uData = null;
          }
          emit();
        });
        driverSub = _db.collection('drivers').doc(uid).snapshots().listen((snap) {
          if (snap.exists) {
            dData = snap.data();
          } else {
            dData = null;
          }
          emit();
        });
      },
      onCancel: () {
        userSub?.cancel();
        driverSub?.cancel();
      }
    );

    return controller.stream;
  }

  /// Perfil de una cuenta del panel recién creada en Firebase Auth.
  Future<void> saveStaffProfile({
    required String uid,
    required String name,
    required String email,
    required String role,
    String? createdBy,
  }) =>
      _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'role': role,
        'status': 'approved',
        'isBlocked': false,
        'createdAt': FieldValue.serverTimestamp(),
        if (createdBy != null) 'createdBy': createdBy,
      });

  Future<void> setStaffRole(String uid, String role) =>
      _db.collection('users').doc(uid).set({'role': role}, SetOptions(merge: true));

  /// Bloquea / desbloquea cualquier cuenta (staff, conductor o pasajero).
  Future<void> setAccountBlocked(String uid, bool blocked) =>
      _updateAccountDocs(uid, {'isBlocked': blocked});

  /// Notificar al conductor
  Future<void> notifyDriver(String driverId, String title, String body) async {
    await _db.collection('notifications').add({
      'userId': driverId,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  /// Leer notificaciones del usuario actual
  Stream<List<Map<String, dynamic>>> userNotifications(String uid) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Marcar notificación como leída
  Future<void> markNotificationRead(String notifId) => _db
      .collection('notifications')
      .doc(notifId)
      .set({'isRead': true}, SetOptions(merge: true));

  /// Añadir transacción manual y actualizar billetera
  Future<void> addManualTransaction(
    String walletId,
    double amount,
    String reason,
  ) async {
    await _db.collection('transactions').add({
      'walletId': walletId,
      'amount': amount,
      'type': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Actualizar balance
    await _db.collection('wallets').doc(walletId).set({
      'balance': FieldValue.increment(amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  
  Stream<List<Map<String, dynamic>>> allReports() => _db
      .collection('reports')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((q) => q.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Stream<List<Map<String, dynamic>>> chatMessagesForTrip(String tripId) => _db
      .collection('trips')
      .doc(tripId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((q) => q.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Future<void> sendSupportMessage(String tripId, String text) async {
    await _db.collection('trips').doc(tripId).collection('messages').add({
      'senderId': 'support',
      'senderName': 'Soporte Admin',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendTripMessage({
    required String tripId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    await _db.collection('trips').doc(tripId).collection('messages').add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // =====================================================
  //  SOPORTE CENTRALIZADO (`support_chats`)
  // =====================================================

  /// Envío de mensaje de soporte para el Administrador hacia cualquier usuario
  Future<void> sendAdminSupportMessage({
    required String userId,
    required String userName,
    required String text,
  }) async {
    final chatRef = _db.collection('support_chats').doc(userId);

    await chatRef.collection('messages').add({
      'senderId': 'admin',
      'senderName': 'Soporte Admin',
      'text': text,
      'isAdmin': true,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRef.set({
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadByAdmin': false,
    }, SetOptions(merge: true));
  }

  /// Envío de mensaje de soporte desde la app del Conductor
  Future<void> sendDriverSupportMessage({
    required String driverUid,
    required String driverName,
    required String text,
  }) async {
    final chatRef = _db.collection('support_chats').doc(driverUid);

    await chatRef.collection('messages').add({
      'text': text,
      'senderId': driverUid,
      'senderName': driverName.isNotEmpty ? driverName : 'Conductor',
      'senderRole': 'driver',
      'isAdmin': false, 
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRef.set({
      'userId': driverUid,
      'driverId': driverUid,
      'name': driverName.isNotEmpty ? driverName : 'Conductor',
      'role': 'driver',
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadByAdmin': true, 
    }, SetOptions(merge: true));
  }

  /// Envío de mensaje de soporte para el Pasajero
  Future<void> sendPassengerSupportMessage({
    required String passengerUid,
    required String passengerName,
    required String text,
  }) async {
    final chatRef = _db.collection('support_chats').doc(passengerUid);

    await chatRef.collection('messages').add({
      'text': text,
      'senderId': passengerUid,
      'senderName': passengerName.isNotEmpty ? passengerName : 'Pasajero',
      'senderRole': 'passenger',
      'isAdmin': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRef.set({
      'userId': passengerUid,
      'driverId': passengerUid,
      'name': passengerName.isNotEmpty ? passengerName : 'Pasajero',
      'role': 'passenger',
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadByAdmin': true,
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> allSupportChats() => _db
      .collection('support_chats')
      .snapshots()
      .map((q) => q.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Future<void> markSupportChatRead(String userId) => _db
      .collection('support_chats')
      .doc(userId)
      .set({'unreadByAdmin': false}, SetOptions(merge: true));

  Stream<List<Map<String, dynamic>>> supportMessagesForUser(String userId) => _db
      .collection('support_chats')
      .doc(userId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((q) => q.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  // =====================================================

  Future<void> resolveReport(String id) => _db
      .collection('reports')
      .doc(id)
      .set({'status': 'resolved'}, SetOptions(merge: true));

  /// Todos los usuarios
  Stream<List<Map<String, dynamic>>> allUsers() => _db
      .collection('users')
      .snapshots()
      .map((q) => q.docs.map((d) => {'uid': d.id, ...d.data()}).toList());

  Future<void> updateUserStatus(String uid, {bool? isReported}) {
    final Map<String, dynamic> data = {};
    if (isReported != null) data['isReported'] = isReported;
    return _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  /// Todas las reservas
  Stream<List<Map<String, dynamic>>> allReservations() => _db
      .collection('reservations')
      .orderBy('scheduledAt', descending: false)
      .snapshots()
      .map((q) => q.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  /// Lee `settings/pricing`; si no existe lo crea con los valores por defecto.
  Future<({PricingSettings settings, bool created})> ensurePricingSettings() {
    final ref = _db.collection('settings').doc('pricing');
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        return (settings: PricingSettings.fromMap(snap.data()), created: false);
      }
      final defaults = PricingSettings.fromMap(null);
      tx.set(ref, {
        ...defaults.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return (settings: defaults, created: true);
    });
  }

  /// Transmite en tiempo real la configuración de tarifas (`settings/pricing`).
  Stream<PricingSettings> streamPricingSettings() => _db
      .collection('settings')
      .doc('pricing')
      .snapshots()
      .map((snap) => PricingSettings.fromMap(snap.data()));

  /// Obtiene la configuración actual de tarifas (`settings/pricing`).
  Future<PricingSettings> getPricingSettings() async {
    try {
      final snap = await _db.collection('settings').doc('pricing').get();
      return PricingSettings.fromMap(snap.data());
    } catch (_) {
      return PricingSettings.fromMap(null);
    }
  }

  Future<void> savePricingSettings(PricingSettings settings) =>
      _db.collection('settings').doc('pricing').set({
        ...settings.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Alertas S.O.S. abiertas.
  Stream<List<Map<String, dynamic>>> openAlerts() => _db
      .collection('alerts')
      .where('status', isEqualTo: 'open')
      .snapshots()
      .map((q) => q.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  /// Alertas S.O.S. resueltas (historial).
  Stream<List<Map<String, dynamic>>> resolvedAlerts() => _db
      .collection('alerts')
      .where('status', isEqualTo: 'resolved')
      .snapshots()
      .map((q) => q.docs
      .map((d) => {'id': d.id, ...d.data()})
      .toList());

  Future<void> resolveAlert(String id, {String? notes, String? resolvedBy}) => _db
      .collection('alerts')
      .doc(id)
      .set({
        'status': 'resolved',
        if (notes != null) 'resolutionNotes': notes,
        if (resolvedBy != null) 'resolvedBy': resolvedBy,
        'resolvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> createSosAlert({
    required String driverId,
    required double latitude,
    required double longitude,
    required String city,
    String? phone,
    String? name,
    String? plate,
    String reportedBy = 'driver', 
  }) =>
      _db.collection('alerts').add({
        'type': 'sos',
        'driverId': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'city': city,
        'phone': phone,
        'name': name,
        'plate': plate,
        'reportedBy': reportedBy,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

  // =====================================================================
  // PUBLICIDAD (ADS) Y MÉTRICAS DE SEGUIMIENTO
  // =====================================================================
  Stream<List<Map<String, dynamic>>> streamAds() {
    return _db.collection('ads').orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  Future<void> createAd(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('ads').add(data);
  }

  Future<void> updateAd(String id, Map<String, dynamic> data) async {
    await _db.collection('ads').doc(id).update(data);
  }

  Future<void> toggleAd(String id, bool isActive) async {
    await _db.collection('ads').doc(id).update({'isActive': isActive});
  }

  Future<void> deleteAd(String id) async {
    await _db.collection('ads').doc(id).delete();
  }

  // Métodos añadidos para registrar Vistas y Clics en tiempo real
  Future<void> trackAdView(String adId) async {
    try {
      await _db.collection('ads').doc(adId).update({
        'viewsCount': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  Future<void> trackAdClick(String adId) async {
    try {
      await _db.collection('ads').doc(adId).update({
        'clicksCount': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  // =====================================================================
  // PLANES
  // =====================================================================
  Stream<List<Map<String, dynamic>>> streamPlans() {
    return _db.collection('plans').orderBy('priority', descending: false).snapshots().map(
          (snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  Future<void> updatePlan(PlanModel plan, String updatedBy) async {
    final data = plan.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['updatedBy'] = updatedBy;
    await _db.collection('plans').doc(plan.id).set(data, SetOptions(merge: true));
  }

  Future<void> togglePlanActive(String planId, bool isActive, String updatedBy) async {
    await _db.collection('plans').doc(planId).set({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    }, SetOptions(merge: true));
  }

  Future<void> seedDefaultPlans() async {
    final batch = _db.batch();
    
    // Plan Diario
    final dRef = _db.collection('plans').doc('plan_diario');
    batch.set(dRef, {
      'name': 'Diario',
      'price': 2.50,
      'durationDays': 1,
      'priority': 1,
      'tier': 'diario',
      'benefits': ['Carreras ilimitadas', 'Visibilidad normal', 'Soporte estándar'],
      'isActive': true,
    }, SetOptions(merge: true));

    // Plan Semanal
    final sRef = _db.collection('plans').doc('plan_semanal');
    batch.set(sRef, {
      'name': 'Semanal',
      'price': 15.00,
      'durationDays': 7,
      'priority': 2,
      'tier': 'semanal',
      'benefits': ['Ahorras S/2.50', 'Carreras ilimitadas', 'Mayor visibilidad', 'Soporte prioritario'],
      'isActive': true,
    }, SetOptions(merge: true));

    // Plan Mensual
    final mRef = _db.collection('plans').doc('plan_mensual');
    batch.set(mRef, {
      'name': 'Mensual',
      'price': 50.00,
      'durationDays': 30,
      'priority': 3,
      'tier': 'mensual',
      'benefits': ['Ahorras S/25.00', 'Mejor plan valor/precio', 'Visibilidad TOP', 'Prioridad en la asignación de viajes'],
      'isActive': true,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // =====================================================================
  // SOLICITUDES DE PLANES (REQUESTS)
  // =====================================================================
  Stream<List<Map<String, dynamic>>> streamPendingPlanRequests() {
    return _db
        .collection('plan_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Stream<List<Map<String, dynamic>>> streamAllPlanRequests() {
    return _db
        .collection('plan_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Stream<List<DriverPlanModel>> streamDriverPlans() {
    return _db.collection('driver_plans').snapshots().map(
          (snap) => snap.docs.map((doc) => DriverPlanModel.fromFirestore(doc)).toList(),
        );
  }

  Future<void> createPlanRequest(Map<String, dynamic> data) async {
    final driverId = data['driverId'];
    if (driverId != null) {
      final userDoc = await _db.collection('users').doc(driverId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        data['driverName'] = userData['name'] ?? userData['fullName'] ?? 'Sin nombre';
        data['driverPhone'] = userData['phone'] ?? '';
      }
    }
    
    // Asegurar compatibilidad de duración si el plan usa horas o días
    if (!data.containsKey('durationValue')) {
      data['durationValue'] = data['days'] ?? 1;
      data['durationUnit'] = 'days';
    }

    data['createdAt'] = FieldValue.serverTimestamp();
    data['status'] = 'pending';
    await _db.collection('plan_requests').add(data);
  }

  Future<void> approvePlanRequest(Map<String, dynamic> request, String adminName) async {
    final reqId = request['id'];
    final realAdminName = AuthService.instance.currentUser?.name ?? (adminName.isNotEmpty ? adminName : 'Admin');

    await _db.runTransaction((transaction) async {
      final reqRef = _db.collection('plan_requests').doc(reqId);
      final driverId = request['driverId']?.toString() ?? '';
      final planId = request['planId']?.toString() ?? '';
      final planName = request['planName']?.toString() ?? '';

      // =====================================================================
      // 1. TODAS LAS LECTURAS (READS) PRIMERO
      // =====================================================================
      final reqDoc = await transaction.get(reqRef);
      if (!reqDoc.exists) throw Exception('La solicitud no existe.');
      if (reqDoc.data()?['status'] != 'pending') throw Exception('La solicitud ya fue revisada.');

      DocumentSnapshot? planDoc;
      if (planId.isNotEmpty) {
        final planRef = _db.collection('plans').doc(planId);
        planDoc = await transaction.get(planRef);
      }

      final driverPlanRef = _db.collection('driver_plans').doc(driverId);
      final driverPlanDoc = await transaction.get(driverPlanRef);

      // =====================================================================
      // 2. CÁLCULOS LÓGICOS Y DE FECHAS
      // =====================================================================
      int priority = (request['priority'] as num?)?.toInt() ?? 1;
      Map<String, dynamic> planMergeData = {};
      if (planDoc != null && planDoc.exists && planDoc.data() != null) {
        planMergeData = planDoc.data() as Map<String, dynamic>;
        priority = (planMergeData['priority'] as num?)?.toInt() ?? priority;
      }

      // Extraer la cantidad y la unidad (horas o días)
      final int durationValue = (request['durationValue'] as num?)?.toInt() 
          ?? (request['days'] as num?)?.toInt() 
          ?? 1;
      final String durationUnit = request['durationUnit']?.toString() ?? 'days';

      final planTierKey = PlanTier.resolve({
        ...planMergeData,
        'planName': planName,
        'durationValue': durationValue,
        'durationUnit': durationUnit,
      }).key;

      DateTime startsAt = DateTime.now();
      DateTime expiresAt = DateTime.now();

      // Calcular fecha de expiración según la unidad
      if (durationUnit == 'hours') {
        expiresAt = startsAt.add(Duration(hours: durationValue));
      } else {
        expiresAt = startsAt.add(Duration(days: durationValue));
      }

      // Si el conductor ya cuenta con un plan activo que no ha vencido, acumulamos el tiempo
      if (driverPlanDoc.exists && driverPlanDoc.data() != null) {
        final currentData = driverPlanDoc.data()!;
        final currentExpires = (currentData['expiresAt'] as Timestamp?)?.toDate();
        if (currentExpires != null && currentExpires.isAfter(DateTime.now())) {
          startsAt = (currentData['startsAt'] as Timestamp?)?.toDate() ?? startsAt;
          if (durationUnit == 'hours') {
            expiresAt = currentExpires.add(Duration(hours: durationValue));
          } else {
            expiresAt = currentExpires.add(Duration(days: durationValue));
          }
        }
      }

      // =====================================================================
      // 3. TODAS LAS ESCRITURAS (WRITES) DESPUÉS
      // =====================================================================
      // Marcar el request como aprobado
      transaction.update(reqRef, {
        'status': 'approved',
        'reviewedBy': realAdminName,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      // Actualizar el plan del conductor
      transaction.set(driverPlanRef, {
        'planId': planId,
        'planName': planName,
        'priority': priority,
        'tier': planTierKey,
        'startsAt': startsAt,
        'expiresAt': expiresAt,
        'status': 'active',
        'activatedBy': realAdminName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Actualizar el estado general en el perfil del conductor
      if (driverId.isNotEmpty) {
        final driverRef = _db.collection('drivers').doc(driverId);
        transaction.set(driverRef, {
          'planPaymentStatus': 'active',
          'activePlanId': planId,
          'planName': planName,
          'planPriority': priority,
          'planTier': planTierKey,
          'planExpiresAt': expiresAt,
          'pendingPlanId': FieldValue.delete(),
          'pendingPlanName': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> rejectPlanRequest(Map<String, dynamic> request, String reason, String adminName) async {
    final reqId = request['id'];
    final realAdminName = AuthService.instance.currentUser?.name ?? (adminName.isNotEmpty ? adminName : 'Admin');

    await _db.runTransaction((transaction) async {
      final reqRef = _db.collection('plan_requests').doc(reqId);
      final reqDoc = await transaction.get(reqRef);
      if (!reqDoc.exists) throw Exception('La solicitud no existe.');
      if (reqDoc.data()?['status'] != 'pending') throw Exception('La solicitud ya fue revisada.');

      final driverId = request['driverId']?.toString() ?? '';
      DocumentSnapshot<Map<String, dynamic>>? driverDoc;
      if (driverId.isNotEmpty) {
        driverDoc = await transaction.get(_db.collection('drivers').doc(driverId));
      }

      // 1. Marcar request como rechazado
      transaction.update(reqRef, {
        'status': 'rejected',
        'rejectReason': reason,
        'reviewedBy': realAdminName,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      // 2. Merge en drivers/{driverId}
      if (driverId.isNotEmpty) {
        final driverRef = _db.collection('drivers').doc(driverId);
        final driverData = driverDoc?.data();
        final expiresAt = (driverData?['planExpiresAt'] as Timestamp?)?.toDate();
        final stillActive = driverData?['planPaymentStatus'] == 'active' &&
            expiresAt != null &&
            expiresAt.isAfter(DateTime.now());

        transaction.set(driverRef, {
          if (!stillActive) 'planPaymentStatus': 'rejected',
          'pendingPlanId': FieldValue.delete(),
          'pendingPlanName': FieldValue.delete(),
        }, SetOptions(merge: true));
      }

      // 3. Notificar al conductor
      final notifRef = _db.collection('notifications').doc();
      transaction.set(notifRef, {
        'userId': driverId,
        'title': 'Solicitud de plan rechazada',
        'body': 'Tu pago para el plan ${request['planName']} fue rechazado. Motivo: $reason',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    });
  }

  Future<void> notifyPlanRequestIssue(Map<String, dynamic> request, String message, String adminName) async {
    final reqId = request['id'];
    final driverId = request['driverId']?.toString() ?? '';
    final planName = request['planName']?.toString() ?? '';
    final realAdminName = AuthService.instance.currentUser?.name ?? (adminName.isNotEmpty ? adminName : 'Admin');

    final batch = _db.batch();

    // 1. Notificación al conductor
    final notifRef = _db.collection('notifications').doc();
    batch.set(notifRef, {
      'userId': driverId,
      'title': 'Revisa tu comprobante de pago',
      'body': 'No pudimos reconocer tu comprobante del plan $planName.$message Vuelve a subirlo.',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // 2. Actualizar solicitud en plan_requests
    final reqRef = _db.collection('plan_requests').doc(reqId);
    batch.update(reqRef, {
      'lastWarning': message,
      'lastWarningAt': FieldValue.serverTimestamp(),
      'lastWarningBy': realAdminName,
    });

    await batch.commit();
  }

  // =====================================================================
  // CONFIGURACIÓN Y QR DE PAGO
  // =====================================================================
  Stream<Map<String, dynamic>?> streamPaymentQr() {
    return _db
        .collection('settings')
        .doc('payment_qr')
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }

  Future<void> savePaymentQr({
  required String url,
  required String storagePath,
  String? oldStoragePath,
  String? adminName,
}) async {
  final realAdminName = AuthService.instance.currentUser?.name ?? adminName ?? 'SuperAdmin';
  final docRef = _db.collection('settings').doc('payment_qr');
  
  try {
    await docRef.set({
      'url': url,
      'storagePath': storagePath,
      'label': 'Plin',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': realAdminName,
    }, SetOptions(merge: false)); 
  } catch (e) {
    await DocumentService.instance.deleteStorageFile(storagePath);
    rethrow;
  }

  if (oldStoragePath != null && oldStoragePath.isNotEmpty && oldStoragePath != storagePath) {
    await DocumentService.instance.deleteStorageFile(oldStoragePath);
  }
}

  Future<void> restoreDefaultPaymentQr({String? oldStoragePath}) async {
    await _db.collection('settings').doc('payment_qr').delete();

    if (oldStoragePath != null && oldStoragePath.isNotEmpty) {
      await DocumentService.instance.deleteStorageFile(oldStoragePath);
    }
  }
  Stream<QuerySnapshot<Map<String, dynamic>>> streamPushCampaigns() {
    return _db
        .collection('push_campaigns')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }
}