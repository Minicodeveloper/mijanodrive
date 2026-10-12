class PlanRejectReasons {
  static const List<String> reasons = [
    'El archivo no se reconoce como un comprobante de pago',
    'La imagen está borrosa o ilegible',
    'El monto no coincide con el plan seleccionado',
    'El comprobante ya fue utilizado',
    'Otro (escribir motivo)',
  ];

  static const String other = 'Otro (escribir motivo)';
}
