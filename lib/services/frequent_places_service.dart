import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/frequent_place_model.dart';

class FrequentPlacesService {
  static final FrequentPlacesService instance = FrequentPlacesService._();

  FrequentPlacesService._() {
    _init();
  }

  static const String _boxName = 'frequent_places_box';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache en memoria para carga instantánea
  final List<FrequentPlace> _cachedPlaces = [];
  final StreamController<List<FrequentPlace>> _controller =
      StreamController<List<FrequentPlace>>.broadcast();

  bool _initialized = false;
  StreamSubscription? _firestoreSub;

  List<FrequentPlace> get cachedPlaces => List.unmodifiable(_cachedPlaces);
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  Future<Box> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    await _loadFromLocal();
    _startFirestoreSync();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      _loadFromLocal();
      _startFirestoreSync();
    });
  }

  Future<void> _loadFromLocal() async {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) return;

    try {
      final box = await _getBox();
      final List<FrequentPlace> loaded = [];

      for (var key in box.keys) {
        final keyStr = key.toString();
        if (keyStr.startsWith('${uid}_')) {
          final data = box.get(key);
          if (data is Map) {
            try {
              final map = Map<String, dynamic>.from(data);
              loaded.add(FrequentPlace.fromMap(map));
            } catch (_) {}
          }
        }
      }

      if (loaded.isNotEmpty) {
        _cachedPlaces
          ..clear()
          ..addAll(loaded);
        _controller.add(List.unmodifiable(_cachedPlaces));
      }
    } catch (e) {
      debugPrint('Error cargando lugares frecuentes locales (Hive): $e');
    }
  }

  void _startFirestoreSync() {
    _firestoreSub?.cancel();
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) return;

    try {
      _firestoreSub = _firestore
          .collection('users')
          .doc(uid)
          .collection('frequent_places')
          .snapshots()
          .listen(
        (snapshot) async {
          final List<FrequentPlace> cloudPlaces = [];
          final box = await _getBox();

          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            final place = FrequentPlace.fromMap(data);
            cloudPlaces.add(place);
            await box.put('${uid}_${place.id}', place.toMap());
          }

          if (cloudPlaces.isNotEmpty) {
            _cachedPlaces
              ..clear()
              ..addAll(cloudPlaces);
            _controller.add(List.unmodifiable(_cachedPlaces));
          }
        },
        onError: (e) {
          // Si las reglas en la nube aún no permiten la subcolección, se ignora limpiamente
          debugPrint('Firestore subcolección no sincronizada ($e). Modo local activo.');
        },
      );
    } catch (e) {
      debugPrint('Error al conectar subcolección Firestore: $e');
    }
  }

  Stream<List<FrequentPlace>> streamPlaces([String? uid]) {
    final targetUid = uid ?? _currentUid;
    if (targetUid == null || targetUid.isEmpty) {
      return Stream.value([]);
    }

    // Asegurar carga inicial
    _loadFromLocal();

    return Stream.multi((controller) {
      // Emitir valor actual inmediatamente
      controller.add(List.unmodifiable(_cachedPlaces));

      // Escuchar cambios reactivos
      final sub = _controller.stream.listen(
        (data) => controller.add(data),
        onError: (err) => controller.addError(err),
      );

      controller.onCancel = () => sub.cancel();
    });
  }

  Future<List<FrequentPlace>> getPlaces([String? uid]) async {
    final targetUid = uid ?? _currentUid;
    if (targetUid == null || targetUid.isEmpty) {
      return _cachedPlaces;
    }

    await _loadFromLocal();
    return _cachedPlaces;
  }

  Future<void> savePlace(FrequentPlace place, [String? uid]) async {
    final targetUid = uid ?? _currentUid;
    if (targetUid == null || targetUid.isEmpty) return;

    // 1. Guardar de inmediato en almacenamiento local (Hive)
    try {
      final box = await _getBox();
      await box.put('${targetUid}_${place.id}', place.toMap());

      final idx = _cachedPlaces.indexWhere((p) => p.id == place.id);
      if (idx >= 0) {
        _cachedPlaces[idx] = place;
      } else {
        _cachedPlaces.add(place);
      }
      _controller.add(List.unmodifiable(_cachedPlaces));
    } catch (e) {
      debugPrint('Error guardando lugar en almacenamiento local: $e');
    }

    // 2. Sincronizar en la nube en segundo plano (tolerante a reglas/conexión)
    unawaited(() async {
      try {
        final placeMap = place.toMap();

        // Guardar en el documento del usuario (users/{uid})
        await _firestore.collection('users').doc(targetUid).set({
          'frequentPlaces': {
            place.id: placeMap,
          }
        }, SetOptions(merge: true)).catchError((e) {
          debugPrint('Aviso: Firestore users doc frequentPlaces: $e');
        });

        // Guardar en subcolección (users/{uid}/frequent_places/{id})
        await _firestore
            .collection('users')
            .doc(targetUid)
            .collection('frequent_places')
            .doc(place.id)
            .set(placeMap, SetOptions(merge: true))
            .catchError((e) {
          debugPrint('Aviso: Firestore subcolección frequent_places: $e');
        });
      } catch (e) {
        debugPrint('Aviso en sincronización en segundo plano: $e');
      }
    }());
  }

  Future<void> deletePlace(String placeId, [String? uid]) async {
    final targetUid = uid ?? _currentUid;
    if (targetUid == null || targetUid.isEmpty) return;

    // 1. Eliminar de almacenamiento local
    try {
      final box = await _getBox();
      await box.delete('${targetUid}_$placeId');

      _cachedPlaces.removeWhere((p) => p.id == placeId);
      _controller.add(List.unmodifiable(_cachedPlaces));
    } catch (e) {
      debugPrint('Error eliminando de almacenamiento local: $e');
    }

    // 2. Eliminar en la nube en segundo plano
    unawaited(() async {
      try {
        await _firestore.collection('users').doc(targetUid).update({
          'frequentPlaces.$placeId': FieldValue.delete(),
        }).catchError((_) {});

        await _firestore
            .collection('users')
            .doc(targetUid)
            .collection('frequent_places')
            .doc(placeId)
            .delete()
            .catchError((_) {});
      } catch (e) {
        debugPrint('Aviso al eliminar en Firestore: $e');
      }
    }());
  }
}
