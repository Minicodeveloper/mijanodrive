import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final SoundService instance = SoundService._();

  SoundService._() {
    _init();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  AudioPlayer? _appPlayer;
  AudioPlayer? _notificationPlayer;
  AudioPlayer? _previewPlayer;

  // Rutas por defecto en assets (audioplayers agrega "assets/" automáticamente con AssetSource)
  static const String defaultAppEntryAsset = 'sounds/melodia_app.mp3';
  static const String defaultNotificationAsset = 'sounds/melodia_notificacion.mp3';

  // Configuración en memoria
  String? _appEntrySoundUrl;
  String? _notificationSoundUrl;
  String _appEntrySoundName = 'melodia_app.mp3';
  String _notificationSoundName = 'melodia_notificacion.mp3';
  bool _appEntrySoundEnabled = true;
  bool _notificationSoundEnabled = true;

  bool _initialized = false;
  StreamSubscription? _settingsSub;

  String? get appEntrySoundUrl => _appEntrySoundUrl;
  String? get notificationSoundUrl => _notificationSoundUrl;
  String get appEntrySoundName => _appEntrySoundName;
  String get notificationSoundName => _notificationSoundName;
  bool get appEntrySoundEnabled => _appEntrySoundEnabled;
  bool get notificationSoundEnabled => _notificationSoundEnabled;

  bool get isAppEntryPlaying => _appPlayer?.state == PlayerState.playing;
  bool get isNotificationPlaying => _notificationPlayer?.state == PlayerState.playing;

  Future<void> init() async {
    _init();
  }

  void dispose() {
    _settingsSub?.cancel();
    _appPlayer?.dispose();
    _notificationPlayer?.dispose();
    _previewPlayer?.dispose();
  }

  void _init() {
    if (_initialized) return;
    _initialized = true;

    try {
      _appPlayer = AudioPlayer();
      _notificationPlayer = AudioPlayer();
      _previewPlayer = AudioPlayer();

      // Configurar modo de audio seguro
      _appPlayer?.setReleaseMode(ReleaseMode.stop);
      _notificationPlayer?.setReleaseMode(ReleaseMode.stop);
      _previewPlayer?.setReleaseMode(ReleaseMode.stop);

      _listenSettings();
    } catch (e) {
      debugPrint('Error al inicializar SoundService: $e');
    }
  }

  void _listenSettings() {
    try {
      _settingsSub = _firestore
          .collection('app_settings')
          .doc('sounds')
          .snapshots()
          .listen((doc) {
        if (doc.exists) {
          final data = doc.data() ?? {};
          _appEntrySoundUrl = data['appEntrySoundUrl'];
          _notificationSoundUrl = data['notificationSoundUrl'];
          _appEntrySoundName = data['appEntrySoundName'] ?? 'melodia_app.mp3';
          _notificationSoundName = data['notificationSoundName'] ?? 'melodia_notificacion.mp3';
          _appEntrySoundEnabled = data['appEntrySoundEnabled'] ?? true;
          _notificationSoundEnabled = data['notificationSoundEnabled'] ?? true;
        }
      }, onError: (e) {
        debugPrint('Aviso: Escucha de configuración de sonidos: $e');
      });
    } catch (e) {
      debugPrint('Error conectando a app_settings/sounds: $e');
    }
  }

  // ===========================================================================
  // REPRODUCCIÓN DE SONIDOS EN LA APP
  // ===========================================================================

  /// Reproduce el sonido de bienvenida al ingresar a la app
  Future<void> playAppEntrySound() async {
    if (!_appEntrySoundEnabled) return;

    try {
      _appPlayer ??= AudioPlayer();
      await _appPlayer!.stop();

      if (_appEntrySoundUrl != null && _appEntrySoundUrl!.isNotEmpty) {
        await _appPlayer!.play(UrlSource(_appEntrySoundUrl!));
      } else {
        await _appPlayer!.play(AssetSource(defaultAppEntryAsset));
      }
    } catch (e) {
      debugPrint('Error al reproducir melodia de entrada a la app: $e');
    }
  }

  /// Reproduce el sonido de notificación de la app
  Future<void> playNotificationSound() async {
    if (!_notificationSoundEnabled) return;

    try {
      _notificationPlayer ??= AudioPlayer();
      await _notificationPlayer!.stop();

      if (_notificationSoundUrl != null && _notificationSoundUrl!.isNotEmpty) {
        await _notificationPlayer!.play(UrlSource(_notificationSoundUrl!));
      } else {
        await _notificationPlayer!.play(AssetSource(defaultNotificationAsset));
      }
    } catch (e) {
      debugPrint('Error al reproducir melodia de notificación: $e');
    }
  }

  /// Reproduce una prueba previa de audio (usado en el Panel Admin)
  Future<void> playPreview({
    required String type, // 'app' o 'notification'
    String? customUrl,
  }) async {
    try {
      _previewPlayer ??= AudioPlayer();
      await _previewPlayer!.stop();

      if (customUrl != null && customUrl.isNotEmpty) {
        await _previewPlayer!.play(UrlSource(customUrl));
      } else if (type == 'app') {
        if (_appEntrySoundUrl != null && _appEntrySoundUrl!.isNotEmpty) {
          await _previewPlayer!.play(UrlSource(_appEntrySoundUrl!));
        } else {
          await _previewPlayer!.play(AssetSource(defaultAppEntryAsset));
        }
      } else {
        if (_notificationSoundUrl != null && _notificationSoundUrl!.isNotEmpty) {
          await _previewPlayer!.play(UrlSource(_notificationSoundUrl!));
        } else {
          await _previewPlayer!.play(AssetSource(defaultNotificationAsset));
        }
      }
    } catch (e) {
      debugPrint('Error al reproducir vista previa de audio: $e');
    }
  }

  /// Detiene la reproducción previa
  Future<void> stopPreview() async {
    try {
      await _previewPlayer?.stop();
    } catch (_) {}
  }

  /// Detiene la melodía de bienvenida al entrar a la cuenta
  Future<void> stopAppEntrySound() async {
    try {
      if (_appPlayer != null) {
        await _appPlayer!.stop();
        debugPrint('[SoundService] Melodía de bienvenida detenida al entrar a la cuenta.');
      }
    } catch (e) {
      debugPrint('Error al detener melodía de entrada: $e');
    }
  }

  /// Detiene la melodía de notificación (por ejemplo al descartar/borrar la notificación)
  Future<void> stopNotificationSound() async {
    try {
      if (_notificationPlayer != null) {
        await _notificationPlayer!.stop();
        debugPrint('[SoundService] Melodía de notificación detenida.');
      }
    } catch (e) {
      debugPrint('Error al detener melodía de notificación: $e');
    }
  }

  /// Detiene todas las melodías activas
  Future<void> stopAll() async {
    try {
      await Future.wait([
        stopAppEntrySound(),
        stopNotificationSound(),
        stopPreview(),
      ]);
    } catch (_) {}
  }

  // ===========================================================================
  // MÉTODOS DE ADMINISTRACIÓN (PANEL ADMIN)
  // ===========================================================================

  /// Sube un nuevo archivo de sonido a Firebase Storage y actualiza Firestore
  Future<String?> uploadSoundFile({
    required String type, // 'app' o 'notification'
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final cleanFileName = fileName.replaceAll(RegExp(r'\s+'), '_');
      final path = 'app_sounds/${type}_${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';
      final ref = _storage.ref().child(path);

      final metadata = SettableMetadata(
        contentType: 'audio/mpeg',
        customMetadata: {'type': type, 'originalName': fileName},
      );

      final uploadTask = await ref.putData(fileBytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      if (type == 'app') {
        _appEntrySoundUrl = downloadUrl;
        _appEntrySoundName = fileName;
        await _firestore.collection('app_settings').doc('sounds').set({
          'appEntrySoundUrl': downloadUrl,
          'appEntrySoundName': fileName,
          'appEntrySoundEnabled': _appEntrySoundEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        _notificationSoundUrl = downloadUrl;
        _notificationSoundName = fileName;
        await _firestore.collection('app_settings').doc('sounds').set({
          'notificationSoundUrl': downloadUrl,
          'notificationSoundName': fileName,
          'notificationSoundEnabled': _notificationSoundEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return downloadUrl;
    } catch (e) {
      debugPrint('Error al subir archivo de sonido: $e');
      rethrow;
    }
  }

  /// Restablece el sonido a la melodía predeterminada original del proyecto
  Future<void> resetToDefault(String type) async {
    try {
      if (type == 'app') {
        _appEntrySoundUrl = null;
        _appEntrySoundName = 'melodia_app.mp3';
        await _firestore.collection('app_settings').doc('sounds').set({
          'appEntrySoundUrl': null,
          'appEntrySoundName': 'melodia_app.mp3',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        _notificationSoundUrl = null;
        _notificationSoundName = 'melodia_notificacion.mp3';
        await _firestore.collection('app_settings').doc('sounds').set({
          'notificationSoundUrl': null,
          'notificationSoundName': 'melodia_notificacion.mp3',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error al restablecer sonido por defecto: $e');
      rethrow;
    }
  }

  /// Activa o desactiva la melodía
  Future<void> toggleSound({
    required String type,
    required bool enabled,
  }) async {
    try {
      if (type == 'app') {
        _appEntrySoundEnabled = enabled;
        await _firestore.collection('app_settings').doc('sounds').set({
          'appEntrySoundEnabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        _notificationSoundEnabled = enabled;
        await _firestore.collection('app_settings').doc('sounds').set({
          'notificationSoundEnabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error al cambiar estado de sonido: $e');
    }
  }
}
