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
          // TODO(Equipo): Implementar control de Firebase Auth (Custom Claims).
          // Aquí se debería permitir crear nuevos operadores o revocar sus accesos.
          Text('Gestión de accesos y revocación de tokens.', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
