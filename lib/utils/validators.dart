class Validators {
  /// Valida que el correo tenga un formato correcto (ej: usuario@dominio.com), sin espacios.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo es obligatorio';
    }
    final email = value.trim();
    if (email.contains(' ')) {
      return 'El correo no puede contener espacios';
    }
    // Regex estándar para emails
    final regex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    if (!regex.hasMatch(email)) {
      return 'Ingresa un correo electrónico válido (ej. usuario@gmail.com)';
    }
    return null;
  }

  /// Valida que la contraseña sea obligatoria y tenga mínimo 6 caracteres.
  /// No recorta la contraseña para permitir espacios si el usuario lo desea.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  /// Valida confirmación de contraseña.
  static String? validateConfirmPassword(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Debes confirmar la contraseña';
    }
    if (password != confirmPassword) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  /// Valida nombres, apellidos o campos genéricos requeridos.
  static String? validateName(String? value, {String fieldName = 'El nombre'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es obligatorio';
    }
    return null;
  }

  /// Valida que el DNI tenga 8 dígitos numéricos exactos y no sea secuencial/repetitivo.
  static String? validateDni(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El DNI es obligatorio';
    }
    final dni = value.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(dni)) {
      return 'El DNI debe tener 8 números';
    }
    if (dni == '00000000' || dni == '11111111' || dni == '22222222' || 
        dni == '33333333' || dni == '44444444' || dni == '55555555' || 
        dni == '66666666' || dni == '77777777' || dni == '88888888' || 
        dni == '99999999' || dni == '12345678' || dni == '87654321') {
      return 'DNI no válido';
    }
    return null;
  }
}
