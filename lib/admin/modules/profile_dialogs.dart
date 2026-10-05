import 'package:flutter/material.dart';
import '../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import 'shared_admin_widgets.dart';

/// Misma firma que `_actualizarEstadoDocumento` de admin_app.dart.
typedef DocStatusUpdater = Future<void> Function(
    BuildContext, Driver, String, String, StateSetter);

Widget _kv(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );

Widget _section(String title) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
            color: Colors.black45),
      ),
    );

Future<void> _run(BuildContext context, Future<void> Function() fn, String ok) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await fn();
    messenger.showSnackBar(SnackBar(content: Text(ok)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('No se pudo completar la acción: $e')));
  }
}

Widget _avatar(String name, String? photoUrl, {double radius = 30}) {
  final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
  return CircleAvatar(
    radius: radius,
    backgroundColor: MijanoTheme.sol,
    backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
    child: hasPhoto
        ? null
        : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
                color: MijanoTheme.ink,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.8)),
  );
}

// =====================================================================
//  PERFIL DE CONDUCTOR
// =====================================================================

class _Doc {
  final String title;
  final String? url;
  final String status;
  final String key; // campo `documents.<key>` que se escribe al aprobar/rechazar
  const _Doc(this.title, this.url, this.status, this.key);
}

class DriverProfileDialog extends StatelessWidget {
  final String uid;
  final DocStatusUpdater? onUpdateStatus;
  final bool canSeeMoney;

  const DriverProfileDialog({super.key, required this.uid, this.onUpdateStatus, this.canSeeMoney = false});

  static Future<void> show(BuildContext context, String uid,
          {DocStatusUpdater? onUpdateStatus, bool canSeeMoney = false}) =>
      showDialog(
        context: context,
        builder: (_) => DriverProfileDialog(uid: uid, onUpdateStatus: onUpdateStatus, canSeeMoney: canSeeMoney),
      );

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: StreamBuilder<Driver?>(
          stream: fs.driverStream(uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return _message(context, 'No se pudo cargar el perfil: ${snap.error}');
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 200, child: Center(child: CircularProgressIndicator()));
            }
            final d = snap.data;
            if (d == null) {
              return _message(context, 'No se encontró el perfil del conductor.');
            }
            return _content(context, d);
          },
        ),
      ),
    );
  }

  Widget _message(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ],
        ),
      );

  ({String text, Color color}) _state(Driver d) {
    if (d.isBlocked) return (text: 'Bloqueado', color: Colors.red.shade800);
    switch (d.status) {
      case 'approved':
        return (text: 'Activo', color: Colors.green);
      case 'rejected':
        return (text: 'Rechazado', color: Colors.red);
      default:
        return (text: 'Pendiente', color: Colors.orange);
    }
  }

  List<_Doc> _docs(Driver d) {
    String? s(dynamic v) {
      final t = v?.toString();
      return (t == null || t.isEmpty) ? null : t;
    }

    String st(List<String> keys) {
      for (final k in keys) {
        final v = s(d.documents[k]);
        if (v != null) return v;
      }
      return 'pendiente';
    }

    return [
      _Doc('DNI (Frente)', s(d.documents['docFront']), st(['docFrontStatus']), 'docFrontStatus'),
      _Doc('DNI (Reverso)', s(d.documents['docBack']), st(['docBackStatus']), 'docBackStatus'),
      _Doc('Licencia de Conducir', s(d.licensePhotoUrl) ?? s(d.documents['licensedDocument']),
          st(['licensedDocumentStatus', 'licenseStatus']), 'licensedDocumentStatus'),
      _Doc('SOAT / Revisión Técnica', s(d.soatPhotoUrl) ?? s(d.documents['soatPhoto']),
          st(['soatPhotoStatus', 'soatStatus']), 'soatPhotoStatus'),
      _Doc('Antecedentes Policiales', s(d.documents['policeRecord']),
          st(['policeRecordStatus']), 'policeRecordStatus'),
      _Doc('Antecedentes Penales', s(d.documents['criminalRecord']),
          st(['criminalRecordStatus']), 'criminalRecordStatus'),
      _Doc('Tarjeta de Propiedad', s(d.documents['propertyCardPhoto']),
          st(['propertyCardPhotoStatus']), 'propertyCardPhotoStatus'),
      _Doc('Foto del Vehículo', s(d.documents['vehiclePhoto']),
          st(['vehiclePhotoStatus']), 'vehiclePhotoStatus'),
    ];
  }

  Widget _content(BuildContext context, Driver d) {
    final fs = FirestoreService.instance;
    final state = _state(d);
    final docs = _docs(d);
    final aprobados = docs.where((x) => x.status.toLowerCase() == 'aprobado').length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
          child: Row(
            children: [
              _avatar(d.name, d.photoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: MijanoTheme.ink)),
                    const SizedBox(height: 2),
                    Text(d.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 6),
                    AdminBadge(state.text, state.color),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('Cuenta'),
                _kv('Ciudad', d.city),
                _kv('Registro', formatAdminDate(d.createdAt)),
                _kv('Disponibilidad', d.isAvailable ? 'En línea' : 'Fuera de línea'),
                _kv('Acceso', d.isBlocked ? 'Bloqueado' : 'Permitido'),
                _section('Vehículo y licencia'),
                _kv('Marca', d.vehicleBrand),
                _kv('Modelo', d.vehicleModel),
                _kv('Placa', d.plate),
                _kv('N° de licencia', d.licenseNumber),
                _section('Documentos ($aprobados/${docs.length} aprobados)'),
                for (final doc in docs) _docRow(context, d, doc),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (d.status != 'rejected')
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                  onPressed: () async {
                    final ok = await adminConfirm(context,
                        title: 'Rechazar conductor',
                        body: '¿Rechazar a ${d.name}? No podrá operar hasta ser aprobado de nuevo.',
                        action: 'Rechazar',
                        danger: true);
                    if (!ok || !context.mounted) return;
                    await _run(context, () => fs.approveDriver(d.uid, false),
                        'Conductor rechazado');
                  },
                  child: const Text('Rechazar'),
                ),
              OutlinedButton(
                onPressed: () async {
                  if (!d.isBlocked) {
                    final ok = await adminConfirm(context,
                        title: 'Bloquear acceso',
                        body: '${d.name} no podrá iniciar sesión mientras esté bloqueado.',
                        action: 'Bloquear',
                        danger: true);
                    if (!ok || !context.mounted) return;
                  }
                  if (!context.mounted) return;
                  await _run(
                      context,
                      () => fs.setAccountBlocked(d.uid, !d.isBlocked),
                      d.isBlocked ? 'Conductor desbloqueado' : 'Conductor bloqueado');
                },
                child: Text(d.isBlocked ? 'Desbloquear' : 'Bloquear'),
              ),
              if (d.status != 'approved')
                ElevatedButton(
                  onPressed: () => _run(
                      context, () => fs.approveDriver(d.uid, true), 'Conductor aprobado'),
                  child: const Text('Aprobar'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _docRow(BuildContext context, Driver d, _Doc doc) {
    Color color;
    String label;
    switch (doc.status.toLowerCase()) {
      case 'aprobado':
        color = Colors.green;
        label = 'Aprobado';
        break;
      case 'rechazado':
        color = Colors.red;
        label = 'Rechazado';
        break;
      default:
        color = Colors.orange;
        label = 'Pendiente';
    }
    final hasUrl = doc.url != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(doc.title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          AdminBadge(label, color),
          const SizedBox(width: 4),
          IconButton(
            tooltip: hasUrl ? 'Ver documento' : 'Sin archivo',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.visibility_outlined, size: 20, color: hasUrl ? null : Colors.black26),
            onPressed: hasUrl ? () => _showImage(context, doc.url!) : null,
          ),
          if (onUpdateStatus != null) ...[
            IconButton(
              tooltip: 'Aprobar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
              onPressed: () =>
                  onUpdateStatus!(context, d, doc.key, 'aprobado', (fn) => fn()),
            ),
            IconButton(
              tooltip: 'Rechazar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.cancel_outlined, size: 20, color: Colors.red),
              onPressed: () =>
                  onUpdateStatus!(context, d, doc.key, 'rechazado', (fn) => fn()),
            ),
          ],
        ],
      ),
    );
  }

  void _showImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Previsualización de Documento',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Text('No se pudo cargar la imagen')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
//  PERFIL DE PASAJERO
// =====================================================================

class PassengerProfileDialog extends StatelessWidget {
  final String uid;
  final bool canSeeMoney;
  
  const PassengerProfileDialog({super.key, required this.uid, this.canSeeMoney = false});

  static Future<void> show(BuildContext context, String uid, {bool canSeeMoney = false}) =>
      showDialog(context: context, builder: (_) => PassengerProfileDialog(uid: uid, canSeeMoney: canSeeMoney));

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: fs.userDoc(uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return _msg(context, 'No se pudo cargar el perfil: ${snap.error}');
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 200, child: Center(child: CircularProgressIndicator()));
            }
            final u = snap.data;
            if (u == null) return _msg(context, 'No se encontró el perfil del pasajero.');
            return _content(context, u);
          },
        ),
      ),
    );
  }

  Widget _msg(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ],
        ),
      );

  Widget _content(BuildContext context, Map<String, dynamic> u) {
    final fs = FirestoreService.instance;
    String v(String k) => (u[k] ?? '').toString();
    final name = v('name').isEmpty ? 'Sin nombre' : v('name');
    final blocked = u['isBlocked'] == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
          child: Row(
            children: [
              _avatar(name, v('photoUrl')),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: MijanoTheme.ink)),
                    const SizedBox(height: 6),
                    blocked
                        ? AdminBadge('Bloqueado', Colors.red.shade800)
                        : const AdminBadge('Activo', Colors.green),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('Contacto'),
                _kv('Correo', v('email')),
                _kv('Teléfono', v('phone')),
                _kv('DNI', v('dni')),
                _section('Cuenta'),
                _kv('Ciudad', v('city')),
                _kv('Registro', formatAdminDate(u['createdAt'])),
                _kv('Acceso', blocked ? 'Bloqueado' : 'Permitido'),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () async {
                  if (!blocked) {
                    final ok = await adminConfirm(context,
                        title: 'Bloquear pasajero',
                        body: '$name no podrá iniciar sesión mientras esté bloqueado.',
                        action: 'Bloquear',
                        danger: true);
                    if (!ok || !context.mounted) return;
                  }
                  if (!context.mounted) return;
                  await _run(context, () => fs.setAccountBlocked(uid, !blocked),
                      blocked ? 'Pasajero desbloqueado' : 'Pasajero bloqueado');
                },
                child: Text(blocked ? 'Desbloquear' : 'Bloquear'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
