import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../firebase_options.dart';
import '../../theme.dart';
import 'shared_admin_widgets.dart';

/// Cuentas autorizadas para entrar al panel administrativo.
class SecurityModule extends StatefulWidget {
  const SecurityModule({super.key});

  @override
  State<SecurityModule> createState() => _SecurityModuleState();
}

class _SecurityModuleState extends State<SecurityModule> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'operator';
  bool _saving = false;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<fb.FirebaseAuth> _secondaryAuth() async {
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

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    final email = _email.text.trim();
    try {
      final auth = await _secondaryAuth();
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: _password.text,
      );
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(credential.user!.uid)
          .set({
            'email': email,
            'name': _name.text.trim(),
            'role': _role,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': fb.FirebaseAuth.instance.currentUser?.email,
          });
      await auth.signOut();
      _name.clear();
      _email.clear();
      _password.clear();
      setState(() {
        _message = 'Administrador creado. Puede iniciar sesión con su correo.';
        _error = false;
      });
    } on fb.FirebaseAuthException catch (e) {
      final text = switch (e.code) {
        'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
        'invalid-email' => 'El correo no es válido.',
        'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
        _ => 'No se pudo crear la cuenta (${e.code}).',
      };
      setState(() {
        _message = text;
        _error = true;
      });
    } catch (e) {
      setState(() {
        _message = 'Error al guardar el administrador: $e';
        _error = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminHeader('Seguridad y permisos', 'Roles: SuperAdmin (dueños) y Operador (gerente)'),
          SizedBox(height: 8),
          Text('Gestión de accesos y revocación de tokens. Este módulo requiere configuración avanzada mediante Cloud Functions o Firebase Admin SDK (Plan Blaze). Por ahora, el rol se valida leyendo el campo "role" directamente desde Firestore.', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _noticePlaceholder() => _notice(_message!, _error);

  Widget _notice(String text, bool isError) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    color: (isError ? MijanoTheme.signal : Colors.green).withValues(alpha: .1),
    child: Text(
      text,
      style: TextStyle(
        color: isError ? MijanoTheme.signal : Colors.green.shade700,
      ),
    ),
  );
}
