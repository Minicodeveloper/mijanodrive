import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../utils/driver_docs.dart';
import '../widgets/document_viewer_dialog.dart';
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
    
    int aprobados = 0;
    for (var doc in docs) {
      if (DriverDocs.normalizeStatus(doc.status) == 'approved') {
        aprobados++;
      }
    }

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
              if (d.status != 'approved') ...[
                Builder(builder: (context) {
                  final allApp = DriverDocs.allApproved(d);
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: allApp ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: allApp
                        ? () => _run(context, () => fs.approveDriver(d.uid, true), 'Conductor aprobado')
                        : null,
                    child: Text(allApp ? 'Aprobar' : 'Faltan docs'),
                  );
                }),
              ],
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
    DocumentViewerDialog.show(
      context,
      url: url,
      title: 'Previsualización de Documento',
    );
  }
}

// =====================================================================
//  PERFIL DE PASAJERO (DETALLE COMPLETO Y OBSERVACIÓN DE DNI)
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
    final maxHeight = MediaQuery.of(context).size.height * 0.90;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 700, maxHeight: maxHeight),
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: fs.userDoc(uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return _msg(context, 'No se pudo cargar el perfil del pasajero: ${snap.error}');
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Cargando información del pasajero...', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );

  Widget _content(BuildContext context, Map<String, dynamic> u) {
    final fs = FirestoreService.instance;
    String v(String k) => (u[k] ?? '').toString();
    final name = v('name').isEmpty ? 'Sin nombre' : v('name');
    final blocked = u['isBlocked'] == true;

    final photoUrl = (u['photoUrl'] ?? u['profileImageUrl'])?.toString();
    final dni = v('dni');
    final dniStatus = v('dniStatus').toLowerCase();
    final dniFrontUrl = (u['dniFrontUrl'] ?? u['documents']?['dniFront'])?.toString();
    final dniBackUrl = (u['dniBackUrl'] ?? u['documents']?['dniBack'])?.toString();
    final hasFront = dniFrontUrl != null && dniFrontUrl.trim().isNotEmpty;
    final hasBack = dniBackUrl != null && dniBackUrl.trim().isNotEmpty;

    final phone = v('phone');
    final email = v('email');
    final emergencyPhone = v('emergencyPhone');
    final city = v('city');
    final birthDate = u['birthDate'] != null ? formatAdminDate(u['birthDate']) : (v('birthDate').isNotEmpty ? v('birthDate') : '—');
    final age = u['age'] != null ? '${u['age']} años' : (v('age').isNotEmpty ? '${v('age')} años' : '—');
    final dniVerifiedAt = u['dniVerifiedAt'] != null ? formatAdminDate(u['dniVerifiedAt']) : (v('dniVerifiedAt').isNotEmpty ? v('dniVerifiedAt') : '—');
    final createdAt = formatAdminDate(u['createdAt']);
    final lastSync = formatAdminDate(u['lastFcmUpdate'] ?? u['updatedAt']);
    final biometric = u['biometricEnabled'] == true ? 'Activada (Huella / Rostro)' : 'No configurada';
    final hasFcm = (u['fcmToken'] != null && u['fcmToken'].toString().isNotEmpty) ||
                   (u['fcmTokens'] is List && (u['fcmTokens'] as List).isNotEmpty);
    final rating = (u['rating'] ?? u['passengerRating']) != null ? '${(u['rating'] ?? u['passengerRating'])} ★' : '5.0 ★';
    final totalTrips = (u['totalTrips'] ?? u['tripsCount']) != null ? '${(u['totalTrips'] ?? u['tripsCount'])} viajes' : '0 viajes';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------------- CABECERA PRINCIPAL ----------------
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              _avatar(name, photoUrl, radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: MijanoTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        const AdminBadge('Pasajero', Colors.blueGrey),
                        blocked
                            ? AdminBadge('Bloqueado', Colors.red.shade800)
                            : const AdminBadge('Cuenta Activa', Colors.green),
                        if (dniStatus == 'aprobado' || dniStatus == 'verificado')
                          const AdminBadge('DNI Verificado', Colors.green)
                        else if (hasFront && hasBack)
                          const AdminBadge('DNI por revisar', Colors.blue)
                        else if (dni.isNotEmpty)
                          const AdminBadge('DNI Pendiente', Colors.orange)
                        else
                          const AdminBadge('Sin DNI', Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // ---------------- CONTENIDO CON SCROLL ----------------
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. SECCIÓN DNI AL DERECHO Y AL REVÉS
                _section('Documento Nacional de Identidad (DNI)'),
                const Text(
                  'Inspección visual del documento: observa ambas caras del DNI en alta resolución y valida su autenticidad.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),

                // Tarjetas de DNI Frontal y Posterior
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 480;
                    final frontCard = _buildDniCard(
                      context: context,
                      title: 'DNI Frontal',
                      subtitle: 'Al derecho (Anverso)',
                      url: dniFrontUrl,
                      icon: Icons.badge_outlined,
                      passengerName: name,
                    );
                    final backCard = _buildDniCard(
                      context: context,
                      title: 'DNI Posterior',
                      subtitle: 'Al revés (Reverso)',
                      url: dniBackUrl,
                      icon: Icons.credit_card_outlined,
                      passengerName: name,
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          frontCard,
                          const SizedBox(height: 12),
                          backCard,
                        ],
                      );
                    } else {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: frontCard),
                          const SizedBox(width: 12),
                          Expanded(child: backCard),
                        ],
                      );
                    }
                  },
                ),

                // Barra de Acciones de Aprobación de DNI
                _buildDniActionBar(context, uid, dniStatus, hasFront, hasBack),

                const SizedBox(height: 12),
                _kv('Número DNI', dni),
                _kv('Estado DNI', dniStatus.isNotEmpty ? dniStatus.toUpperCase() : (dni.isNotEmpty ? 'REGISTRADO' : 'NO REGISTRADO')),
                _kv('Validado el', dniVerifiedAt),

                // 2. CONTACTO Y EMERGENCIA FAMILIAR
                _section('Contacto y Emergencia Familiar'),
                _kvCopyable(context, 'Teléfono Celular', phone, isPhone: true),
                _kvCopyable(context, 'Correo Electrónico', email),
                
                // Tarjeta destacada de teléfono de emergencia familiar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: emergencyPhone.isNotEmpty ? const Color(0xFFFEF3C7) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: emergencyPhone.isNotEmpty ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: emergencyPhone.isNotEmpty ? const Color(0xFFD97706) : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.contact_emergency_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contacto de Emergencia Familiar (S.O.S / SAMU)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              emergencyPhone.isNotEmpty
                                  ? emergencyPhone
                                  : 'No registrado por el pasajero en su perfil',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: emergencyPhone.isNotEmpty ? FontWeight.w800 : FontWeight.normal,
                                color: emergencyPhone.isNotEmpty ? const Color(0xFF92400E) : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (emergencyPhone.isNotEmpty) ...[
                        IconButton(
                          tooltip: 'Copiar número de emergencia',
                          icon: const Icon(Icons.copy, size: 18, color: Color(0xFFB45309)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: emergencyPhone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Número de emergencia copiado al portapapeles.')),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Llamar familiar',
                          icon: const Icon(Icons.phone, size: 18, color: Colors.green),
                          onPressed: () async {
                            final uri = Uri.parse('tel:$emergencyPhone');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // 3. DATOS PERSONALES
                _section('Identidad y Datos Personales'),
                _kv('Nombre Completo', name),
                _kv('Fecha de Nacimiento', birthDate),
                _kv('Edad', age),
                _kv('Ciudad / Región', city),

                // 4. DATOS DE CUENTA Y DISPOSITIVO
                _section('Cuenta y Dispositivo'),
                _kvCopyable(context, 'UID de Usuario', uid),
                _kv('Fecha de Registro', createdAt),
                _kv('Última Sincronización', lastSync),
                _kv('Seguridad Biométrica', biometric),
                _kv('Notificaciones Push', hasFcm ? 'Dispositivo vinculado (FCM Activo)' : 'Sin token push registrado'),
                _kv('Acceso a la App', blocked ? 'Bloqueado por Administración' : 'Permitido / Activo'),

                // 5. ACTIVIDAD Y MÉTRICAS
                _section('Actividad y Calificación'),
                _kv('Total de Viajes', totalTrips),
                _kv('Calificación', rating),
              ],
            ),
          ),
        ),

        // ---------------- FOOTER DE ACCIONES ----------------
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('Eliminar pasajero', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final ok = await adminConfirm(
                    context,
                    title: 'Eliminar pasajero definitivamente',
                    body: '¿Estás seguro de eliminar a $name definitivamente? Se borrará su cuenta, DNI, teléfono, fotos y todos sus registros de la base de datos para no dejar datos huérfanos.',
                    action: 'Eliminar definitivamente',
                    danger: true,
                  );
                  if (!ok || !context.mounted) return;
                  Navigator.pop(context);
                  await _run(context, () => fs.deleteUserCompletely(uid), 'Pasajero eliminado completamente');
                },
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: blocked ? Colors.green.shade800 : Colors.red.shade800,
                      side: BorderSide(color: blocked ? Colors.green : Colors.red.shade300),
                    ),
                    icon: Icon(blocked ? Icons.lock_open : Icons.block, size: 16),
                    label: Text(blocked ? 'Desbloquear' : 'Bloquear acceso'),
                    onPressed: () async {
                      if (!blocked) {
                        final ok = await adminConfirm(
                          context,
                          title: 'Bloquear pasajero',
                          body: '$name no podrá iniciar sesión mientras esté bloqueado.',
                          action: 'Bloquear',
                          danger: true,
                        );
                        if (!ok || !context.mounted) return;
                      }
                      if (!context.mounted) return;
                      await _run(
                        context,
                        () => fs.setAccountBlocked(uid, !blocked),
                        blocked ? 'Pasajero desbloqueado' : 'Pasajero bloqueado',
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tarjeta visual para observar el DNI al derecho y al revés
  Widget _buildDniCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String? url,
    required IconData icon,
    required String passengerName,
  }) {
    final hasUrl = url != null && url.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera de la tarjeta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: hasUrl ? const Color(0xFFD97706) : Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: hasUrl ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Previsualización de la imagen
          if (hasUrl)
            InkWell(
              onTap: () {
                DocumentViewerDialog.show(
                  context,
                  url: url,
                  title: '$title ($subtitle) · $passengerName',
                );
              },
              child: Container(
                height: 140,
                color: Colors.black.withOpacity(0.04),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      },
                      errorBuilder: (ctx, _, __) => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey, size: 32),
                            SizedBox(height: 4),
                            Text('Error cargando imagen', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Ampliar',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 120,
              color: Colors.grey.shade50,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 34),
                    const SizedBox(height: 6),
                    Text(
                      'Foto no adjuntada aún',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

          // Barra inferior de botones si hay URL
          if (hasUrl)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.fullscreen, size: 15),
                    label: const Text('Ver en grande', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      DocumentViewerDialog.show(
                        context,
                        url: url,
                        title: '$title ($subtitle) · $passengerName',
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Abrir enlace directo',
                    icon: const Icon(Icons.open_in_new, size: 15),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final uri = Uri.tryParse(url);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Barra de control administrativo para aprobar o rechazar el DNI
  Widget _buildDniActionBar(BuildContext context, String uid, String currentStatus, bool hasFront, bool hasBack) {
    final fs = FirestoreService.instance;
    final isApproved = currentStatus == 'aprobado' || currentStatus == 'verificado';
    final isRejected = currentStatus == 'rechazado';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isApproved
            ? Colors.green.shade50
            : (isRejected ? Colors.red.shade50 : const Color(0xFFFFFBEB)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isApproved
              ? Colors.green.shade200
              : (isRejected ? Colors.red.shade200 : Colors.amber.shade300),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isApproved
                ? Icons.check_circle
                : (isRejected ? Icons.cancel : Icons.info_outline),
            color: isApproved
                ? Colors.green.shade700
                : (isRejected ? Colors.red.shade700 : Colors.amber.shade800),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isApproved
                  ? 'DNI Verificado y Aprobado'
                  : (isRejected
                      ? 'DNI Observado / Rechazado'
                      : (hasFront && hasBack
                          ? 'DNI completo por revisar'
                          : 'DNI incompleto')),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isApproved
                    ? Colors.green.shade900
                    : (isRejected ? Colors.red.shade900 : Colors.amber.shade900),
              ),
            ),
          ),
          if (hasFront || hasBack) ...[
            if (!isApproved)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Aprobar DNI', style: TextStyle(fontSize: 11)),
                onPressed: () async {
                  await _run(
                    context,
                    () => fs.updatePassengerDniStatus(uid, 'aprobado'),
                    'DNI del pasajero aprobado con éxito',
                  );
                },
              ),
            if (isApproved)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade800,
                  side: BorderSide(color: Colors.orange.shade400),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.edit, size: 13),
                label: const Text('Revertir', style: TextStyle(fontSize: 11)),
                onPressed: () async {
                  await _run(
                    context,
                    () => fs.updatePassengerDniStatus(uid, 'pendiente'),
                    'DNI marcado como pendiente',
                  );
                },
              ),
            if (!isRejected) ...[
              const SizedBox(width: 6),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.close, size: 13),
                label: const Text('Observar', style: TextStyle(fontSize: 11)),
                onPressed: () async {
                  await _run(
                    context,
                    () => fs.updatePassengerDniStatus(uid, 'rechazado'),
                    'DNI rechazado/observado',
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Fila de clave/valor con botón para copiar al portapapeles
  Widget _kvCopyable(BuildContext context, String label, String value, {bool isPhone = false}) {
    final display = value.trim().isEmpty ? '—' : value.trim();
    final hasVal = value.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    display,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      fontFamily: label.contains('UID') ? 'monospace' : null,
                    ),
                  ),
                ),
                if (hasVal) ...[
                  IconButton(
                    tooltip: 'Copiar $label',
                    icon: const Icon(Icons.copy, size: 14, color: Colors.grey),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value.trim()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$label copiado al portapapeles.'), duration: const Duration(seconds: 2)),
                      );
                    },
                  ),
                  if (isPhone)
                    IconButton(
                      tooltip: 'Llamar',
                      icon: const Icon(Icons.phone, size: 14, color: Colors.green),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () async {
                        final uri = Uri.parse('tel:${value.trim()}');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
