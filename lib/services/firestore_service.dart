import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/trip_model.dart';
import '../models/driver_model.dart';
import '../models/wallet_model.dart';
import '../models/tariff_model.dart';

class FirestoreService {
  static final FirestoreService instance = FirestoreService._();
  FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- Usuarios ----
  Future<void> saveUser(User user) =>
      _db.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));

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

  Future<void> updateDriverLocation(String uid, double lat, double lng) => _db
      .collection('drivers')
      .doc(uid)
      .set({'currentLatitude': lat, 'currentLongitude': lng},
      SetOptions(merge: true));

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
  Stream<List<Trip>> pendingTripsForCity(String city) => _db
      .collection('trips')
      .where('city', isEqualTo: city)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((q) => q.docs.map((d) => Trip.fromFirestore(d)).toList());

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
      .where('status', whereIn: ['pending', 'accepted', 'active'])
      .snapshots()
      .map((q) => q.docs.map((d) => Trip.fromFirestore(d)).toList());

  /// Conductores pendientes de aprobación optimizados para la consola web.
  Stream<List<Driver>> pendingDrivers() => _db
      .collection('users')
      .where('role', isEqualTo: 'driver')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((q) {
    return q.docs.map((d) {
      try {
        return Driver.fromFirestore(d);
      } catch (e) {
        return null;
      }
    }).whereType<Driver>().toList();
  });

  /// Todos los conductores (aprobados + pendientes) para el mapa en vivo.
  Stream<List<Driver>> allDrivers() => _db
      .collection('drivers')
      .snapshots()
      .map((q) => q.docs.map((d) => Driver.fromFirestore(d)).toList());

  Future<void> approveDriver(String uid, bool approved) => _db
      .collection('users')
      .doc(uid)
      .set({'isApproved': approved, 'status': approved ? 'approved' : 'rejected'}, SetOptions(merge: true));

  Future<void> updateDriverStatus(String uid, {bool? isApproved, bool? isBlocked, bool? isRejected}) {
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
    return _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

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
  Future<void> addManualTransaction(String walletId, double amount, String reason) async {
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
      'isAdmin': false, // 👈 Esto hace que aparezca a la derecha como "Tú"
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRef.set({
      'userId': driverUid,
      'driverId': driverUid,
      'name': driverName.isNotEmpty ? driverName : 'Conductor',
      'role': 'driver',
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadByAdmin': true, // 👈 Alerta al panel admin
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

  /// Stream para listar todos los chats de soporte activos en la consola web
  Stream<List<Map<String, dynamic>>> allSupportChats() => _db
      .collection('support_chats')

      .snapshots()

      .map((q) {
    print('🔥 Documentos encontrados en support_chats: ${q.docs.length}');
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  });

  /// 🌟 STREAM UNIVERSAL: Lee los mensajes de soporte de cualquier usuario (Conductor o Pasajero)
  Stream<List<Map<String, dynamic>>> supportMessagesForUser(String userId) => _db
      .collection('support_chats')
      .doc(userId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((q) => q.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  /// Stream específico para conductor
  Stream<List<Map<String, dynamic>>> supportMessagesForDriver(String driverUid) =>
      supportMessagesForUser(driverUid);

  /// Stream específico para pasajero
  Stream<List<Map<String, dynamic>>> supportMessagesForPassenger(String passengerUid) =>
      supportMessagesForUser(passengerUid);

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
  Future<({PricingSettings settings, bool created})>
  ensurePricingSettings() {
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
      _db.collection('settings').doc('pricing').set(
        {...settings.toMap(), 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  /// Alertas S.O.S. abiertas.
  Stream<List<Map<String, dynamic>>> openAlerts() => _db
      .collection('alerts')
      .where('status', isEqualTo: 'open')
      .snapshots()
      .map((q) => q.docs
      .map((d) => {'id': d.id, ...d.data()})
      .toList());

  Future<void> resolveAlert(String id) => _db
      .collection('alerts')
      .doc(id)
      .set({'status': 'resolved'}, SetOptions(merge: true));

  Future<void> createSosAlert({
    required String driverId,
    required double latitude,
    required double longitude,
    required String city,
  }) =>
      _db.collection('alerts').add({
        'type': 'sos',
        'driverId': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'city': city,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
}