class RoleHelper {
  /// Normaliza el string de rol a lowercase para comparaciones seguras.
  static String normalizeRole(String? role) {
    if (role == null) return '';
    return role.trim().toLowerCase();
  }

  /// Verifica si el rol corresponde a un Super Administrador
  static bool isSuperAdmin(String? role) {
    final r = normalizeRole(role);
    return r == 'admin' || r == 'superadmin';
  }

  /// Verifica si el rol corresponde a un Gerente / Operador
  static bool isManager(String? role) {
    final r = normalizeRole(role);
    return r == 'operator' || r == 'operador' || r == 'gerente';
  }

  /// Verifica si el rol corresponde a Soporte
  static bool isSupport(String? role) {
    final r = normalizeRole(role);
    return r == 'support' || r == 'soporte';
  }

  /// Verifica si el rol corresponde a Control
  static bool isControl(String? role) {
    final r = normalizeRole(role);
    return r == 'control';
  }

  /// Verifica si el rol tiene acceso al panel de administración (staff)
  static bool isStaff(String? role) {
    return isSuperAdmin(role) || isManager(role) || isSupport(role) || isControl(role);
  }
}
