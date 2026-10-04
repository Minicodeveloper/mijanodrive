---
name: gestor-svg-figma
description: Se activa cuando el usuario proporciona código SVG, adjunta un archivo .svg exportado de Figma, o pide "usa este svg", "reemplaza el icono por este svg", "añade este svg para que quede igual al figma" o trabaje con vectores de Figma para integrarlos en Flutter.
---

# Gestor de SVGs de Figma para Flutter

## Propósito
Recibir vectores en formato SVG directamente desde Figma, guardarlos en el proyecto, asegurar que el entorno pueda compilarlos y reemplazarlos en el código Flutter con precisión milimétrica píxel por píxel (*Pixel-Perfect*).

---

## Flujo Operativo de Coordinación

```
[Usuario envía SVG / exportación de Figma]
                 │
                 ▼
 1. Almacenamiento directo en `assets/icons/` (o `assets/images/`)
                 │
                 ▼
 2. Verificación de `flutter_svg` y rutas en `pubspec.yaml`
                 │
                 ▼
 3. Inserción con `SvgPicture.asset()` en la vista Flutter
                 │
                 ▼
 4. Coordinación con `replicador-figma-flutter` para alineación y escala
                 │
                 ▼
 5. Análisis estático (`dart analyze`) y reporte conciso al usuario
```

---

## Directivas Obligatorias de Ejecución

### 1. Ubicación y Guardado de Archivos
* **Ruta estándar:** Todo archivo o contenido SVG debe guardarse dentro de la carpeta `assets/icons/` (o `assets/images/` en caso de ilustraciones complejas o fondos).
* **Nomenclatura:** Nombrar siempre en minúsculas y `snake_case` descriptivo:
  * Iconos: `ic_camion_repartidor.svg`, `ic_cliente_vector.svg`, `ic_candado_seguridad.svg`.
  * Ilustraciones: `il_bienvenida_repartidor.svg`, `il_pedido_vacio.svg`.
* **Escritura directa:** El agente debe emplear directamente la herramienta `write_to_file` para crear y persistir el archivo `.svg` en el disco local de inmediato. Nunca pedirle al usuario que cree o guarde el archivo manualmente.

### 2. Verificación de Dependencias y Assets
* **Paquete `flutter_svg`:** Verificar que `flutter_svg` esté declarado en `pubspec.yaml` dentro de `dependencies:`.
  * Si no está presente, agregarlo (ej. `flutter_svg: ^2.0.10` o superior) y ejecutar `flutter pub get`.
* **Declaración de Assets:** Confirmar que la carpeta de assets esté registrada bajo la sección `flutter: -> assets:` en `pubspec.yaml`:
  ```yaml
  flutter:
    assets:
      - assets/icons/
      - assets/images/
  ```

### 3. Integración en el Código Flutter
* **Prohibición de `Image.asset()`:** Nunca utilizar `Image.asset()` ni `ImageIcon()` para cargar archivos `.svg`, ya que genera errores en tiempo de ejecución (`Exception: Invalid image data`).
* **Import obligatorio:**
  ```dart
  import 'package:flutter_svg/flutter_svg.dart';
  ```
* **Implementación con `SvgPicture.asset()`:**
  ```dart
  SvgPicture.asset(
    'assets/icons/nombre_del_icono.svg',
    width: ancho_medido_en_figma,
    height: alto_medido_en_figma,
    fit: BoxFit.contain,
    colorFilter: color_deseado != null
        ? ColorFilter.mode(color_deseado, BlendMode.srcIn)
        : null, // Úsalo únicamente si el vector requiere teñirse
  )
  ```
* **Fidelidad Dimensional:** Respetar rigurosamente las medidas exactas (`width` y `height`) y la relación de aspecto obtenidas de Figma para evitar cualquier distorsión visual del vector.

### 4. Trabajo Conjunto con `replicador-figma-flutter`
Cuando el usuario solicite replicar una vista indicando *"haz esto igual a esta captura pero usando este svg"* o combinando diseños visuales con código SVG:
1. **Fase Gestor SVG (`gestor-svg-figma`):**
   * Extrae el código XML del SVG o guarda el archivo en `assets/icons/`.
   * Verifica dependencias y rutas de assets en el entorno.
2. **Fase Replicador UI (`replicador-figma-flutter`):**
   * Ubica el archivo de la pantalla correspondiente dentro de `lib/`.
   * Inserta el widget `SvgPicture.asset` con su jerarquía, contenedores, márgenes (`Padding`), radios de borde (`BorderRadius`) y decoraciones idénticas a la captura o panel.
3. **Fase de Validación y Entrega:**
   * Ejecutar análisis estático para garantizar ausencia de advertencias.
   * Notificar al usuario con un reporte breve indicando el asset generado y la pantalla actualizada para que acepte los cambios en el editor.

---

## Tabla de Errores Comunes y Soluciones

| Error / Mala Práctica | Causa | Solución Correcta |
|---|---|---|
| `Image.asset('assets/icons/ico.svg')` | Flutter no decodifica SVG nativamente con ImageProvider. | Reemplazar por `SvgPicture.asset('assets/icons/ico.svg')`. |
| Icono desalineado o deformado | No definir `width`, `height` o usar `BoxFit.fill`. | Usar las dimensiones exactas de Figma con `fit: BoxFit.contain`. |
| Color no cambia con el tema | El SVG tiene colores hexadecimales fijos en los atributos `fill`. | Aplicar `colorFilter: ColorFilter.mode(color, BlendMode.srcIn)`. |
| `AssetNotFoundException` | La ruta `assets/icons/` no está registrada en `pubspec.yaml`. | Registrar `- assets/icons/` bajo `flutter: assets:` y correr `flutter pub get`. |
