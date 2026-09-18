import 'package:flutter/material.dart';
import 'shared_admin_widgets.dart';

class SecurityModule extends StatelessWidget {
  const SecurityModule({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(28),
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
}
