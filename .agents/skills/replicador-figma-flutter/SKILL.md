---
name: replicador-figma-flutter
description: >-
  Se activa automáticamente siempre que el usuario diga "este igual a este panel del figma",
  "hazlo igual a este panel del figma", adjunte capturas de pantalla de Figma,
  pida replicar vistas píxel por píxel o maquetar interfaces idénticas a un diseño visual en Flutter.
---

# Replicador Figma a Flutter

Esta habilidad instruye al agente para actuar con precisión milimétrica al transformar capturas de pantalla, paneles o diseños de Figma en código Flutter funcional, limpio y de alta fidelidad visual (*Pixel-Perfect*).

---

## Directivas Obligatorias de Ejecución

El agente **DEBE** seguir estrictamente las siguientes cuatro directivas al ejecutarse:

### 1. Inspección Visual Obligatoria (No asumir nada)
Al recibir una imagen o captura de un panel (sea de Cliente, Mayorista, Minorista, Repartidor o Admin):
- **Jerarquía de composición:** Detectar la estructura base (`Scaffold`, `AppBar`, `Column`, `Row`, `Stack`, `ListView`, `Card`, etc.).
- **Paleta cromática exacta:** Extraer los códigos hexadecimales reales (`#RRGGBB` o `Color(0xFF...)`) de fondos, bordes, iconos y textos.
- **Tipografía y escala:** Identificar peso visual (*light*, *regular*, *semi-bold*, *bold*), tamaño relativo y familia tipográfica; si el proyecto ya cuenta con temas o fuentes globales (como `AppTheme` o `Josefin Sans`), integrarlo dinámicamente sin forzar valores arbitrarios.
- **Espaciados y proporciones:** Respetar márgenes externos (`Padding`/`EdgeInsets`), separaciones verticales y horizontales (`SizedBox`), radios de curvatura en bordes (`BorderRadius.circular(...)`) y elevaciones/sombras (`BoxShadow`).

### 2. Fidelidad Estricta al Diseño
- **No omitir ningún elemento:** No cambiar la distribución ni la jerarquía de los componentes.
- **No inventar componentes:** No agregar botones, iconos, tarjetas ni textos por iniciativa propia que no estén presentes en el diseño suministrado.
- **Alineación exacta:** Todo elemento debe conservar su alineación precisa (`start`, `center`, `end`, `spaceBetween`, etc.) tal como figura en la captura de Figma.

### 3. Buenas Prácticas en Flutter
- **Prevención de desbordes de pantalla:** Evitar errores de *RenderFlex overflowed* (Right/Bottom overflowed) envolviendo columnas, filas y áreas de contenido dinámico en `Expanded`, `Flexible` o contenedores con scroll (`SingleChildScrollView`, `ListView`, `CustomScrollView`) cuando corresponda.
- **Modularidad y limpieza:** Separar widgets reutilizables en componentes limpios y legibles para evitar métodos `build()` masivos y código redundante.
- **Null Safety y const:** Utilizar constructores `const` siempre que sea posible para optimizar el árbol de widgets.

### 4. Modo de Operación Autónomo (Edición directa de archivos)
- **Cero código suelto en el chat:** No devolver bloques de código largos para copiar y pegar en la respuesta conversacional.
- **Ubicación en el proyecto:** Identificar el archivo existente correspondiente en el proyecto o crear el nuevo archivo `.dart` directamente dentro de `lib/` (por ejemplo en `lib/pages/`, `lib/screens/` o `lib/widgets/`).
- **Escritura directa:** Escribir o modificar el código fuente directamente en el disco utilizando las herramientas del entorno (`write_to_file`, `replace_file_content`).
- **Resumen conciso:** Una vez aplicados los cambios en los archivos, notificar al usuario de forma breve y precisa qué archivos fueron creados o actualizados para que revise y acepte los cambios en el editor.

---

## Flujo de Trabajo Operativo

```
[Captura o Panel de Figma recibida]
                 │
                 ▼
 1. Análisis visual exhaustivo (colores, fuentes, padding, bordes)
                 │
                 ▼
 2. Búsqueda de archivo destino o creación de nuevo .dart en lib/
                 │
                 ▼
 3. Edición directa de archivos en disco (código Flutter limpio, sin overflow)
                 │
                 ▼
 4. Verificación de imports y análisis estático
                 │
                 ▼
 5. Reporte breve al usuario indicando archivos modificados
```
