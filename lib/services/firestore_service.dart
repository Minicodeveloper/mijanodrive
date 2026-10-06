import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/trip_model.dart';
import '../models/driver_model.dart';
import '../models/wallet_model.dart';
import '../models/tariff_model.dart';
import '../utils/role_helper.dart';

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
  Future<String> createTrip(Trip trip) async {
    final ref = await _db.collection('trips').add(trip.toMap());
    return ref.id;
  }

  Future<void> updateTrip(String id, Map<String, dynamic> data) =>
      _db.collection('trips').doc(id).set(data, SetOptions(merge: true));

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

  /// Todos los viajes activos (pending/accepted/active) para la consola.
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

  /// Todos los conductores (aprobados + pendientes) combinando 'users' y 'drivers'.
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

  Future<void> approveDriver(String uid, bool approved) => _updateAccountDocs(uid, {
        'isApproved': approved,
        'status': approved ? 'approved' : 'rejected',
      });

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

  /// Roles guardados en `users.role` que pueden entrar al panel.
  /// 'admin' / 'superAdmin' = SuperAdmin (dueños) · 'operator' = Gerente.
  static const List<String> staffRoles = ['admin', 'superAdmin', 'operator'];

  /// Cuentas del panel (SuperAdmin y Gerente).
  Stream<List<Map<String, dynamic>>> staffAccounts() => _db
      .collection('users')
      .where('role', whereIn: staffRoles)
      .snapshots()
      .map((q) => q.docs.map((d) => {'uid': d.id, ...d.data()}).toList());

  /// Documento `users/{uid}` en vivo (null si no existe).
  Stream<Map<String, dynamic>?> userDoc(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? {'uid': d.id, ...?d.data()} : null);

  /// Conductor en vivo combinando `users/{uid}` y `drivers/{uid}`.
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

  /// Todos los reportes (Moderación)
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
    String reportedBy = 'driver', // 'driver' o 'passenger'
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
}
