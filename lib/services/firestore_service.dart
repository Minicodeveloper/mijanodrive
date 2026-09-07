import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/trip_model.dart';
import '../models/driver_model.dart';
import '../models/wallet_model.dart';

/// Acceso a Firestore (proyecto mijanodrive-peru).
/// Métodos defensivos: devuelven null/[] si algo falla, no crashean.
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

  /// Conductores pendientes de aprobación.
  Stream<List<Driver>> pendingDrivers() => _db
      .collection('drivers')
      .where('isApproved', isEqualTo: false)
      .snapshots()
      .map((q) => q.docs.map((d) => Driver.fromFirestore(d)).toList());

  /// Todos los conductores (aprobados + pendientes) para el mapa en vivo.
  Stream<List<Driver>> allDrivers() => _db
      .collection('drivers')
      .snapshots()
      .map((q) => q.docs.map((d) => Driver.fromFirestore(d)).toList());

  Future<void> approveDriver(String uid, bool approved) => _db
      .collection('drivers')
      .doc(uid)
      .set({'isApproved': approved}, SetOptions(merge: true));

  /// Todas las ciudades para el módulo de tarifas.
  Stream<List<Map<String, dynamic>>> allCities() => _db
      .collection('cities')
      .snapshots()
      .map((q) => q.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList());

  Future<void> updateCity(String id, Map<String, dynamic> data) =>
      _db.collection('cities').doc(id).set(data, SetOptions(merge: true));

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
}
