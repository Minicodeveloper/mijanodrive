import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import 'admin_app.dart';

/// Pantalla de inicio de sesión del panel administrativo.
/// Funciona en web y en móvil. Usa Firebase Auth (email/contraseña)
/// y valida que el usuario exista en la colección `admins` de Firestore.
///
/// Botón oculto: mantener presionado el logo 3 segundos abre el
/// diálogo para crear el primer superAdmin (solo si no existe ninguno).
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, this.openFirstAdminDialog = false});

  /// Permite que la app móvil abra el mismo flujo inicial que la web.
  final bool openFirstAdminDialog;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.openFirstAdminDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onLogoLongPress());
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────
  // LOGIN
  // ────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      final uid = cred.user?.uid;
      if (uid == null) {
        setState(() => _error = 'No se pudo autenticar. Intenta de nuevo.');
        return;
      }

      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .get();

      if (!adminDoc.exists) {
        await fb.FirebaseAuth.instance.signOut();
        setState(
          () => _error = 'Esta cuenta no tiene permisos de administrador.',
        );
        return;
      }

      final data = adminDoc.data()!;
      final roleStr = (data['role'] ?? 'operator') as String;
      final role = roleStr == 'superAdmin'
          ? AdminRole.superAdmin
          : AdminRole.operator;

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AdminApp(role: role)),
      );
    } on fb.FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'No existe una cuenta con ese correo.';
        case 'wrong-password':
          msg = 'Contraseña incorrecta.';
        case 'invalid-email':
          msg = 'El correo electrónico no es válido.';
        case 'user-disabled':
          msg = 'Esta cuenta ha sido deshabilitada.';
        case 'too-many-requests':
          msg = 'Demasiados intentos. Espera un momento.';
        case 'invalid-credential':
          msg = 'Credenciales inválidas. Verifica tu correo y contraseña.';
        default:
          msg = 'Error de autenticación (${e.code}).';
      }
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ────────────────────────────────────────────
  // CREAR PRIMER ADMIN (botón oculto)
  // ────────────────────────────────────────────
  Future<void> _onLogoLongPress() async {
    // Verificar si ya existen admins.
    try {
      final snap = await FirebaseFirestore.instance
          .collection('admins')
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ya existe al menos un administrador. '
              'Usa el panel para gestionar usuarios.',
            ),
            backgroundColor: MijanoTheme.ink,
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al verificar admins: $e'),
          backgroundColor: MijanoTheme.signal,
        ),
      );
      return;
    }

    if (!mounted) return;

    // No hay admins → mostrar diálogo de creación.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateFirstAdminDialog(),
    );
  }

  // ────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: MijanoTheme.sol,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: isWide ? 420 : double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo — long-press oculto para crear primer admin
                  GestureDetector(
                    onLongPress: _onLogoLongPress,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 100,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.admin_panel_settings,
                        size: 64,
                        color: MijanoTheme.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Panel Administrativo',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: MijanoTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mijano Drive',
                    style: TextStyle(
                      fontSize: 14,
                      color: MijanoTheme.ink.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingresa tu correo';
                      }
                      if (!v.contains('@')) return 'Correo no válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Ingresa tu contraseña';
                      }
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Error
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MijanoTheme.signal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: MijanoTheme.signal,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: MijanoTheme.signal,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Botón login
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: MijanoTheme.sol,
                              ),
                            )
                          : const Text('Ingresar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  DIÁLOGO: CREAR PRIMER SUPER-ADMIN
// ══════════════════════════════════════════════════════════════

class _CreateFirstAdminDialog extends StatefulWidget {
  const _CreateFirstAdminDialog();

  @override
  State<_CreateFirstAdminDialog> createState() =>
      _CreateFirstAdminDialogState();
}

class _CreateFirstAdminDialogState extends State<_CreateFirstAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Crear usuario en Firebase Auth.
      final cred = await fb.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );

      final uid = cred.user?.uid;
      if (uid == null) throw Exception('No se obtuvo UID');

      // 2. Registrar en la colección `admins` como superAdmin.
      await FirebaseFirestore.instance.collection('admins').doc(uid).set({
        'email': _emailCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'role': 'superAdmin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Cerrar sesión para que inicie sesión por el flujo normal.
      await fb.FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ SuperAdmin creado. Ahora inicia sesión.'),
          backgroundColor: Colors.green,
        ),
      );
    } on fb.FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Ya existe una cuenta con ese correo.';
        case 'weak-password':
          msg = 'La contraseña es muy débil (mínimo 6 caracteres).';
        case 'invalid-email':
          msg = 'El correo no es válido.';
        default:
          msg = 'Error: ${e.code} — ${e.message}';
      }
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.shield, color: MijanoTheme.ink),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Crear primer SuperAdmin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No existe ningún administrador registrado. '
                  'Crea el primer SuperAdmin para acceder al panel.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 20),

                // Nombre
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    if (!v.contains('@')) return 'Correo no válido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Contraseña
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Confirmar contraseña
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _create(),
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    if (v != _passCtrl.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: MijanoTheme.signal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _create,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MijanoTheme.sol,
                  ),
                )
              : const Text('Crear SuperAdmin'),
        ),
      ],
    );
  }
}
