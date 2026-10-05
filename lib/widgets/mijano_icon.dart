import 'package:flutter/material.dart';

/// Icono del mototaxi (PNG propio de Mijano Drive).
///
/// [size] es el ALTO en píxeles. Por defecto conserva los colores originales
/// del PNG; [opacity] sirve para estados "apagados" (p. ej. listas vacías).
class MototaxiIcon extends StatelessWidget {
  static const String asset = 'assets/images/ic_mototaxi_marker.png';

  final double size;
  final double opacity;

  const MototaxiIcon({super.key, this.size = 24, this.opacity = 1.0});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      // Si el asset falta, no rompe la pantalla: cae al icono de Material.
      errorBuilder: (_, __, ___) => Icon(Icons.two_wheeler, size: size),
    );
    if (opacity >= 1.0) return image;
    return Opacity(opacity: opacity, child: image);
  }
}

/// Igual que [Icon], pero si recibe [Icons.two_wheeler] muestra el PNG del
/// mototaxi. Sirve para pantallas que reciben el icono como parámetro.
/// El PNG conserva sus colores, por eso ignora [color] para la moto.
class MijanoIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;

  const MijanoIcon(this.icon, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    if (icon == Icons.two_wheeler) {
      // El PNG es vertical y tiene margen transparente: se agranda un poco
      // para que se vea del mismo peso visual que un icono de Material.
      return MototaxiIcon(size: (size ?? 24) * 1.15);
    }
    return Icon(icon, size: size, color: color);
  }
}
