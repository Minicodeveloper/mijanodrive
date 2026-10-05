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
    final regex = RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$");
    if (!regex.hasMatch(email)) {
      return 'Ingresa un correo electrónico válido';
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
}
