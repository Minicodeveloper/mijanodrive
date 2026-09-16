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
          const AdminHeader(
            'Seguridad y permisos',
            'Crea y revisa las cuentas autorizadas para el panel',
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('admins').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return _notice(
                  'No se pudo leer admins: ${snapshot.error}',
                  true,
                );
              final docs = snapshot.data?.docs ?? const [];
              return Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.admin_panel_settings),
                      title: Text('Administradores registrados'),
                    ),
                    if (docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Todavía no hay administradores registrados.',
                        ),
                      )
                    else
                      for (final doc in docs)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: MijanoTheme.sol,
                            child: Icon(
                              doc.data()['role'] == 'superAdmin'
                                  ? Icons.shield
                                  : Icons.person,
                              color: MijanoTheme.ink,
                            ),
                          ),
                          title: Text(
                            doc.data()['name'] as String? ?? 'Sin nombre',
                          ),
                          subtitle: Text(
                            '${doc.data()['email'] ?? 'Sin correo'} · ${doc.data()['role'] ?? 'operator'}',
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Crear administrador',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Correo'),
                      validator: (v) => v == null || !v.contains('@')
                          ? 'Correo no válido'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      validator: (v) => v == null || v.length < 6
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: const InputDecoration(labelText: 'Rol'),
                      items: const [
                        DropdownMenuItem(
                          value: 'superAdmin',
                          child: Text('SuperAdmin'),
                        ),
                        DropdownMenuItem(
                          value: 'operator',
                          child: Text('Operador'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _role = value ?? 'operator'),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      _noticePlaceholder(),
                    ],
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _createAdmin,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add),
                      label: Text(_saving ? 'Creando…' : 'Crear administrador'),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
