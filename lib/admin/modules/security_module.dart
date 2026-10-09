import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../firebase_options.dart';
import '../../models/driver_model.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../widgets/mijano_icon.dart';
import '../../utils/validators.dart';
import 'profile_dialogs.dart';
import 'shared_admin_widgets.dart';

// ---------------------------------------------------------------------
//  Roles
//  · users.role = 'admin' (o 'superAdmin')  -> SuperAdmin (dueños)
//  · users.role = 'operator'                -> Gerente
//  · users.role = 'support'                 -> Soporte
//  · users.role = 'control'                 -> Control
//  · users.role = 'driver' / 'passenger'    -> solo apps móviles
// ---------------------------------------------------------------------
const _roleSuperAdmin = 'admin';
const _roleManager = 'operator';
const _roleSupport = 'support';
const _roleControl = 'control';

String _norm(dynamic r) =>
    (r ?? '').toString().toLowerCase().replaceAll('_', '').replaceAll(' ', '');

bool _isSuper(Map<String, dynamic>? u) {
  final r = _norm(u?['role']);
  return r == 'admin' || r == 'superadmin';
}

bool _isManager(Map<String, dynamic>? u) {
  final r = _norm(u?['role']);
  return r == 'operator' || r == 'gerente';
}

bool _isSupportRole(Map<String, dynamic>? u) {
  final r = _norm(u?['role']);
  return r == 'support' || r == 'soporte';
}

bool _isControlRole(Map<String, dynamic>? u) {
  final r = _norm(u?['role']);
  return r == 'control';
}

bool _isPassenger(Map<String, dynamic> u) {
  final r = _norm(u['role']);
  return r.isEmpty || r == 'passenger' || r == 'pasajero';
}

String _nameOf(Map<String, dynamic> u) {
  final n = (u['name'] ?? '').toString();
  return n.isEmpty ? 'Sin nombre' : n;
}

/// Gestión de accesos: cuentas del panel (SuperAdmin / Gerente),
/// conductores y pasajeros. Solo visible para SuperAdmin.
class SecurityModule extends StatefulWidget {
  const SecurityModule({super.key});

  @override
  State<SecurityModule> createState() => _SecurityModuleState();
}

class _SecurityModuleState extends State<SecurityModule> {
  final fs = FirestoreService.instance;
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _tab = 0; // 0: Equipo, 1: Conductores, 2: Pasajeros

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  //  Utilidades
  // ------------------------------------------------------------------
  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _run(Future<void> Function() fn, String okMsg) async {
    try {
      await fn();
      if (mounted) _snack(okMsg);
    } catch (e) {
      if (mounted) _snack('No se pudo completar la acción: $e', error: true);
    }
  }

  Widget? _guard(AsyncSnapshot<dynamic> snap) {
    if (snap.hasError) {
      return adminCard(
        child: Text('No se pudo cargar la lista: ${snap.error}',
            style: TextStyle(color: Colors.red.shade700)),
      );
    }
    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return null;
  }

  Future<fb.FirebaseAuth> _secondaryAuth() async {
    // App secundaria: crear la cuenta NO cierra la sesión del SuperAdmin actual.
    const appName = 'admin-account-creator';
    FirebaseApp app;
    try {
      app = Firebase.app(appName);
    } catch (_) {
      app = await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return fb.FirebaseAuth.instanceFor(app: app);
  }

  Future<void> _indexDni() async {
    final ok = await adminConfirm(
      context,
      title: 'Indexar DNI',
      body: 'Se revisarán todos los usuarios y se creará su índice de DNI si es válido y no existe. Esto evitará duplicados en nuevos registros.',
      action: 'Iniciar',
    );
    if (!ok || !mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      int added = 0;
      List<String> conflicts = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dni = data['dni']?.toString().trim();
        final uid = doc.id;
        final name = data['name'] ?? 'Sin nombre';
        final email = data['email'] ?? 'Sin correo';

        if (dni != null && RegExp(r'^\d{8}$').hasMatch(dni)) {
          final indexDoc = await FirebaseFirestore.instance.collection('dni_index').doc(dni).get();
          if (!indexDoc.exists) {
            await FirebaseFirestore.instance.collection('dni_index').doc(dni).set({
              'uid': uid,
              'createdAt': FieldValue.serverTimestamp(),
            });
            added++;
          } else if (indexDoc.data()?['uid'] != uid) {
            conflicts.add('$dni -> $name ($email, $uid)');
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      if (conflicts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Proceso terminado. DNI nuevos indexados: $added.')));
      } else {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Conflictos detectados (DNI duplicado)'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DNI nuevos indexados: $added'),
                  const SizedBox(height: 8),
                  const Text('Estos usuarios comparten DNI con alguien más:'),
                  ...conflicts.map((c) => Text(c, style: const TextStyle(fontSize: 12, color: Colors.red))),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ------------------------------------------------------------------
  //  Build + control de acceso
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final me = fb.FirebaseAuth.instance.currentUser;
    if (me == null) return _denied('Inicia sesión para administrar permisos.');

    // El menú ya oculta "Permisos" a los gerentes, pero se vuelve a verificar
    // contra Firestore: el rol que llega por parámetro no es una garantía.
    return StreamBuilder<Map<String, dynamic>?>(
      stream: fs.userDoc(me.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final mine = snap.data;
        if (!_isSuper(mine) || mine?['isBlocked'] == true) {
          return _denied('Solo un SuperAdmin puede gestionar permisos.');
        }
        return _content(me.uid);
      },
    );
  }

  Widget _denied(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.black38),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _content(String myUid) {
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 720;
      return SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 14 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdminHeader('Permisos y accesos',
                'Quién puede entrar al panel y estado de cada cuenta'),
            _rolesLegend(),
            const SizedBox(height: 20),
            AdminFilterBar(
              tabs: const ['Equipo del panel', 'Conductores', 'Pasajeros'],
              selected: _tab,
              onSelected: (i) => setState(() => _tab = i),
              searchCtrl: _searchCtrl,
              searchHint: 'Buscar por nombre o correo...',
              onSearch: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _indexDni,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Indexar DNI existentes'),
                style: ElevatedButton.styleFrom(backgroundColor: MijanoTheme.sol, foregroundColor: MijanoTheme.ink),
              ),
            ),
            const SizedBox(height: 16),
            if (_tab == 0)
              _staffTab(myUid)
            else if (_tab == 1)
              _driversTab()
            else
              _passengersTab(),
          ],
        ),
      );
    });
  }

  Widget _rolesLegend() {
    Widget line(IconData icon, Color color, String title, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MijanoIcon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '$title  ',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: text, style: const TextStyle(color: Colors.black87)),
                  ]),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );

    return adminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(Icons.verified_user, Colors.deepPurple, 'SuperAdmin (dueños)',
              'Acceso total: tarifas, permisos, montos del panel y todas las cuentas.'),
          line(Icons.manage_accounts, Colors.blue, 'Gerente',
              'Panel sin montos, pasajeros, conductores, soporte y alertas S.O.S. Sin Tarifas ni Permisos.'),
          line(Icons.chat, Colors.green, 'Soporte',
              'Solo ve el grupo SEGURIDAD (Soporte y Alertas S.O.S.). Sin acceso a Permisos ni configuraciones.'),
          line(Icons.supervised_user_circle, Colors.teal, 'Control',
              'Solo ve el grupo GENERAL (Panel, Pasajeros, Conductores). Sin acceso a Tarifas, Seguridad ni montos.'),
          line(Icons.two_wheeler, Colors.orange, 'Conductor / Pasajero',
              'Solo usan las apps móviles. Aquí puedes aprobar, rechazar o bloquear su acceso.'),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  //  Fila genérica de cuenta
  // ------------------------------------------------------------------
  Widget _accountRow({
    required String name,
    required String subtitle,
    String? photoUrl,
    required List<Widget> badges,
    Widget? menu,
    VoidCallback? onTap,
  }) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: MijanoTheme.sol,
              backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
              child: hasPhoto
                  ? null
                  : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: MijanoTheme.ink, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 4,
                children: badges,
              ),
            ),
            if (menu != null) menu else const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _listCard(List<Widget> rows, String emptyText) {
    return adminCard(
      padding: const EdgeInsets.all(12),
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(emptyText)),
            )
          : Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }

  // ------------------------------------------------------------------
  //  TAB 1 · Equipo del panel (SuperAdmin + Gerente)
  // ------------------------------------------------------------------
  Widget _staffTab(String myUid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.staffAccounts(),
      builder: (context, snap) {
        final g = _guard(snap);
        if (g != null) return g;

        final staff = [...(snap.data ?? <Map<String, dynamic>>[])]
          ..sort((a, b) => _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase()));

        final supers = staff.where(_isSuper).length;
        final managers = staff.where(_isManager).length;
        final supports = staff.where(_isSupportRole).length;
        final controls = staff.where(_isControlRole).length;
        final activeSupers =
            staff.where((u) => _isSuper(u) && u['isBlocked'] != true).length;

        final q = _query.toLowerCase();
        final filtered = q.isEmpty
            ? staff
            : staff
                .where((u) =>
                    _nameOf(u).toLowerCase().contains(q) ||
                    (u['email'] ?? '').toString().toLowerCase().contains(q))
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminStatsGrid(items: [
              AdminStat('SuperAdmins', '$supers', Icons.verified_user, Colors.deepPurple),
              AdminStat('Gerentes', '$managers', Icons.manage_accounts, Colors.blue),
              AdminStat('Ctr/Soporte', '${supports+controls}', Icons.security, Colors.green),
            ]),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Nueva cuenta'),
                onPressed: _openCreateDialog,
              ),
            ),
            const SizedBox(height: 12),
            _listCard(
              [for (final u in filtered) _staffRow(u, myUid, activeSupers)],
              'No hay cuentas del panel para mostrar.',
            ),
          ],
        );
      },
    );
  }

  Widget _staffRow(Map<String, dynamic> u, String myUid, int activeSupers) {
    final isMe = u['uid'] == myUid;
    final isSuper = _isSuper(u);
    final isManager = _isManager(u);
    final isSupport = _isSupportRole(u);
    final isControl = _isControlRole(u);
    final blocked = u['isBlocked'] == true;
    // Nunca dejar el sistema sin un SuperAdmin activo.
    final lastSuper = isSuper && !blocked && activeSupers <= 1;
    final email = (u['email'] ?? '').toString();

    final items = <PopupMenuEntry<String>>[
      if (!isMe && !lastSuper) ...[
        if (!isSuper) const PopupMenuItem(value: 'toSuper', child: Text('Cambiar a SuperAdmin')),
        if (!isManager) const PopupMenuItem(value: 'toManager', child: Text('Cambiar a Gerente')),
        if (!isSupport) const PopupMenuItem(value: 'toSupport', child: Text('Cambiar a Soporte')),
        if (!isControl) const PopupMenuItem(value: 'toControl', child: Text('Cambiar a Control')),
      ],
      if (!isMe && !lastSuper)
        PopupMenuItem(
          value: blocked ? 'enable' : 'disable',
          child: Text(blocked ? 'Habilitar acceso' : 'Deshabilitar acceso'),
        ),
      if (email.isNotEmpty)
        const PopupMenuItem(
          value: 'reset',
          child: Text('Enviar restablecimiento de contraseña'),
        ),
    ];

    return _accountRow(
      name: _nameOf(u),
      subtitle: email.isEmpty ? 'Sin correo' : email,
      badges: [
        if (isMe) const AdminBadge('Tú', Colors.teal),
        if (isSuper) const AdminBadge('SuperAdmin', Colors.deepPurple),
        if (isManager) const AdminBadge('Gerente', Colors.blue),
        if (isSupport) const AdminBadge('Soporte', Colors.green),
        if (isControl) const AdminBadge('Control', Colors.teal),
        blocked
            ? AdminBadge('Deshabilitado', Colors.red.shade800)
            : const AdminBadge('Activo', Colors.green),
      ],
      menu: items.isEmpty
          ? null
          : PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              tooltip: lastSuper ? 'Único SuperAdmin activo' : 'Acciones',
              onSelected: (v) => _onStaffAction(v, u),
              itemBuilder: (_) => items,
            ),
    );
  }

  Future<void> _onStaffAction(String action, Map<String, dynamic> u) async {
    final uid = u['uid'].toString();
    final name = _nameOf(u);
    switch (action) {
      case 'toSuper':
        final ok = await adminConfirm(context,
            title: 'Cambiar a SuperAdmin',
            body: '$name tendrá acceso total: tarifas, permisos, montos y todas las cuentas.',
            action: 'Cambiar');
        if (!ok || !mounted) return;
        await _run(() => fs.setStaffRole(uid, _roleSuperAdmin), '$name ahora es SuperAdmin');
        break;
      case 'toManager':
        final ok = await adminConfirm(context,
            title: 'Cambiar a Gerente',
            body: '$name perderá el acceso a Tarifas, Permisos y montos del panel.',
            action: 'Cambiar',
            danger: true);
        if (!ok || !mounted) return;
        await _run(() => fs.setStaffRole(uid, _roleManager), '$name ahora es Gerente');
        break;
      case 'toSupport':
        final ok = await adminConfirm(context,
            title: 'Cambiar a Soporte',
            body: '$name solo podrá acceder a Soporte y Alertas S.O.S.',
            action: 'Cambiar',
            danger: true);
        if (!ok || !mounted) return;
        await _run(() => fs.setStaffRole(uid, _roleSupport), '$name ahora es Soporte');
        break;
      case 'toControl':
        final ok = await adminConfirm(context,
            title: 'Cambiar a Control',
            body: '$name solo podrá acceder a la pestaña General (Panel, Pasajeros, Conductores).',
            action: 'Cambiar',
            danger: true);
        if (!ok || !mounted) return;
        await _run(() => fs.setStaffRole(uid, _roleControl), '$name ahora es Control');
        break;
      case 'disable':
        final ok = await adminConfirm(context,
            title: 'Deshabilitar acceso',
            body: '$name no podrá iniciar sesión mientras esté deshabilitado. Si ya tiene una sesión abierta, esta seguirá activa hasta que la cierre.',
            action: 'Deshabilitar',
            danger: true);
        if (!ok || !mounted) return;
        await _run(() => fs.setAccountBlocked(uid, true), 'Acceso de $name deshabilitado');
        break;
      case 'enable':
        await _run(() => fs.setAccountBlocked(uid, false), 'Acceso de $name habilitado');
        break;
      case 'reset':
        final email = (u['email'] ?? '').toString();
        await _run(
          () => fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email),
          'Correo de restablecimiento enviado a $email',
        );
        break;
    }
  }

  // ------------------------------------------------------------------
  //  Crear cuenta del panel
  // ------------------------------------------------------------------
  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateStaffDialog(onCreate: _createStaff),
    );
    if (created == true && mounted) {
      _snack('Cuenta creada. Ya puede iniciar sesión con su correo.');
    }
  }

  /// Devuelve null si todo salió bien, o el mensaje de error para mostrar.
  Future<String?> _createStaff(
      String name, String email, String password, String role) async {
    fb.FirebaseAuth? auth;
    fb.UserCredential? cred;
    try {
      auth = await _secondaryAuth();
      cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
      await fs.saveStaffProfile(
        uid: cred.user!.uid,
        name: name,
        email: email,
        role: role,
        createdBy: fb.FirebaseAuth.instance.currentUser?.email,
      );
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
        'invalid-email' => 'El correo no es válido.',
        'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
        _ => 'No se pudo crear la cuenta (${e.code}).',
      };
    } catch (e) {
      // El perfil no se guardó: se elimina la cuenta de Auth para no dejarla huérfana.
      try {
        await cred?.user?.delete();
      } catch (_) {}
      return 'No se pudo guardar el perfil: $e';
    } finally {
      try {
        await auth?.signOut();
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------------
  //  TAB 2 · Conductores
  // ------------------------------------------------------------------
  Widget _driversTab() {
    return StreamBuilder<List<Driver>>(
      stream: fs.allDrivers(),
      builder: (context, snap) {
        final g = _guard(snap);
        if (g != null) return g;

        final drivers = snap.data ?? [];
        final approved = drivers.where((d) => d.status == 'approved' && !d.isBlocked).length;
        final pending = drivers.where((d) => d.status == 'pending').length;
        final blocked = drivers.where((d) => d.isBlocked).length;

        final q = _query.toLowerCase();
        final filtered = q.isEmpty
            ? drivers
            : drivers
                .where((d) =>
                    d.name.toLowerCase().contains(q) ||
                    d.email.toLowerCase().contains(q) ||
                    d.plate.toLowerCase().contains(q))
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminStatsGrid(items: [
              AdminStat('Aprobados', '$approved', Icons.check_circle, Colors.green),
              AdminStat('Pendientes', '$pending', Icons.access_time, Colors.orange),
              AdminStat('Bloqueados', '$blocked', Icons.block, Colors.red),
            ]),
            const SizedBox(height: 16),
            _listCard(
              [for (final d in filtered) _driverRow(d)],
              'No hay conductores para mostrar.',
            ),
          ],
        );
      },
    );
  }

  Widget _driverRow(Driver d) {
    Widget status;
    if (d.isBlocked) {
      status = AdminBadge('Bloqueado', Colors.red.shade800);
    } else if (d.status == 'approved') {
      status = const AdminBadge('Activo', Colors.green);
    } else if (d.status == 'rejected') {
      status = const AdminBadge('Rechazado', Colors.red);
    } else {
      status = const AdminBadge('Pendiente', Colors.orange);
    }
    return _accountRow(
      name: d.name,
      subtitle: d.plate.isEmpty ? d.email : '${d.email} · ${d.plate}',
      photoUrl: d.photoUrl,
      badges: [const AdminBadge('Conductor', Colors.orange), status],
      onTap: () => DriverProfileDialog.show(context, d.uid),
      menu: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        onSelected: (v) => _onDriverAction(v, d),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'profile', child: Text('Ver perfil')),
          if (d.status != 'approved') const PopupMenuItem(value: 'approve', child: Text('Aprobar')),
          if (d.status != 'rejected') const PopupMenuItem(value: 'reject', child: Text('Rechazar')),
          PopupMenuItem(
            value: d.isBlocked ? 'unblock' : 'block',
            child: Text(d.isBlocked ? 'Desbloquear' : 'Bloquear acceso'),
          ),
        ],
      ),
    );
  }

  Future<void> _onDriverAction(String action, Driver d) async {
    switch (action) {
      case 'profile':
        DriverProfileDialog.show(context, d.uid);
        break;
      case 'approve':
        await _run(() => fs.approveDriver(d.uid, true), '${d.name} aprobado');
        break;
      case 'reject':
        final ok = await adminConfirm(context,
            title: 'Rechazar conductor',
            body: '¿Rechazar a ${d.name}? No podrá operar hasta ser aprobado de nuevo.',
            action: 'Rechazar',
            danger: true);
        if (!ok || !mounted) return;
        await _run(() => fs.approveDriver(d.uid, false), '${d.name} rechazado');
        break;
      case 'block':
        final ok = await adminConfirm(context,
            title: 'Bloquear acceso',
            body: '${d.name} no podrá iniciar sesión mientras esté bloqueado.',
            action: 'Bloquear',
            danger: true);
        if (!ok || !mounted) return;
        await _run(() => fs.setAccountBlocked(d.uid, true), '${d.name} bloqueado');
        break;
      case 'unblock':
        await _run(() => fs.setAccountBlocked(d.uid, false), '${d.name} desbloqueado');
        break;
    }
  }

  // ------------------------------------------------------------------
  //  TAB 3 · Pasajeros
  // ------------------------------------------------------------------
  Widget _passengersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fs.allUsers(),
      builder: (context, snap) {
        final g = _guard(snap);
        if (g != null) return g;

        final passengers = (snap.data ?? <Map<String, dynamic>>[]).where(_isPassenger).toList()
          ..sort((a, b) => _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase()));
        final blocked = passengers.where((u) => u['isBlocked'] == true).length;

        final q = _query.toLowerCase();
        final filtered = q.isEmpty
            ? passengers
            : passengers
                .where((u) =>
                    _nameOf(u).toLowerCase().contains(q) ||
                    (u['email'] ?? '').toString().toLowerCase().contains(q) ||
                    (u['phone'] ?? '').toString().contains(_query))
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminStatsGrid(items: [
              AdminStat('Total', '${passengers.length}', Icons.people, Colors.blueGrey),
              AdminStat('Activos', '${passengers.length - blocked}', Icons.check_circle, Colors.green),
              AdminStat('Bloqueados', '$blocked', Icons.block, Colors.red),
            ]),
            const SizedBox(height: 16),
            _listCard(
              [for (final u in filtered) _passengerRow(u)],
              'No hay pasajeros para mostrar.',
            ),
          ],
        );
      },
    );
  }

  Widget _passengerRow(Map<String, dynamic> u) {
    final blocked = u['isBlocked'] == true;
    final email = (u['email'] ?? '').toString();
    final phone = (u['phone'] ?? '').toString();
    final uid = u['uid'].toString();
    return _accountRow(
      name: _nameOf(u),
      subtitle: email.isNotEmpty ? email : (phone.isNotEmpty ? phone : 'Sin contacto'),
      photoUrl: (u['photoUrl'] ?? '').toString(),
      badges: [
        blocked
            ? AdminBadge('Bloqueado', Colors.red.shade800)
            : const AdminBadge('Activo', Colors.green),
      ],
      onTap: () => PassengerProfileDialog.show(context, uid),
      menu: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        onSelected: (v) => _onPassengerAction(v, u),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'profile', child: Text('Ver perfil')),
          PopupMenuItem(
            value: blocked ? 'unblock' : 'block',
            child: Text(blocked ? 'Desbloquear' : 'Bloquear acceso'),
          ),
        ],
      ),
    );
  }

  Future<void> _onPassengerAction(String action, Map<String, dynamic> u) async {
    final uid = u['uid'].toString();
    final name = _nameOf(u);
    switch (action) {
      case 'profile':
        PassengerProfileDialog.show(context, uid);
        break;
      case 'block':
        final ok = await adminConfirm(context,
            title: 'Bloquear pasajero',
            body: '$name no podrá iniciar sesión mientras esté bloqueado.',
            action: 'Bloquear',
            danger: true);
        if (!ok || !mounted) return;
        await _run(() => fs.setAccountBlocked(uid, true), '$name bloqueado');
        break;
      case 'unblock':
        await _run(() => fs.setAccountBlocked(uid, false), '$name desbloqueado');
        break;
    }
  }
}

// =====================================================================
//  Diálogo "Nueva cuenta del panel"
// =====================================================================
class _CreateStaffDialog extends StatefulWidget {
  /// Devuelve null si se creó bien, o el mensaje de error.
  final Future<String?> Function(String name, String email, String password, String role)
      onCreate;
  const _CreateStaffDialog({required this.onCreate});

  @override
  State<_CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends State<_CreateStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = _roleManager;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await widget.onCreate(
      _name.text.trim(),
      _email.text.trim(),
      _password.text,
      _role,
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva cuenta del panel'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: Validators.validateName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña temporal',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: Validators.validatePassword,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: _roleManager, child: Text('Gerente')),
                    DropdownMenuItem(value: _roleControl, child: Text('Control')),
                    DropdownMenuItem(value: _roleSupport, child: Text('Soporte')),
                    DropdownMenuItem(value: _roleSuperAdmin, child: Text('SuperAdmin (dueño)')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? _roleManager),
                ),
                const SizedBox(height: 8),
                Text(
                  _role == _roleSuperAdmin
                      ? 'Acceso total: tarifas, permisos, montos y todas las cuentas.'
                      : _role == _roleManager
                          ? 'Gestiona conductores, pasajeros, soporte y alertas. Sin Tarifas ni Permisos.'
                          : _role == _roleControl
                              ? 'Solo ve el Panel general, conductores y pasajeros. Sin seguridad, tarifas ni dinero.'
                              : 'Solo ve el grupo SEGURIDAD (Soporte y Alertas). Sin permisos.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MijanoTheme.signal.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(color: MijanoTheme.signal)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear cuenta'),
        ),
      ],
    );
  }
}
