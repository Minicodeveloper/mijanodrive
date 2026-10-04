# Ejemplo de Habilidad Real: Guía de Estilos Flutter

Este ejemplo muestra cómo estructurar una habilidad completa siguiendo las mejores prácticas de Antigravity y el principio de divulgación progresiva.

---

### Archivo `SKILL.md`:

```markdown
---
name: guia-estilos-flutter
description: Aplica el sistema de diseño corporativo (colores, tipografía, componentes y tokens visuales) en interfaces Flutter. Úsalo cuando el usuario pida crear, estilizar, diseñar o refactorizar vistas, componentes o widgets de la app.
---

# Guía de Estilos y Diseño Flutter

Esta habilidad instruye al agente para actuar como Diseñador de Producto y desarrollador UI especializado en Flutter, asegurando consistencia visual absoluta con el tema de la aplicación.

Fuente de verdad: `lib/theme/app_theme.dart`

---

## Criterios de Selección de Componentes

- **¿Se necesita un botón de acción principal?** -> Usar botón con `AppTheme.primary` (#1E40AF) y altura mínima de 48px.
- **¿Se muestra un estado de entrega o inventario?** -> Usar `AppTheme.success` (#22C55E) para completado o `AppTheme.warning` (#D97706) para pendiente.
- **¿Se requiere consultar tokens completos?** -> Ver [Tokens de Color y Superficies](./references/tokens_tema.md).

---

## Flujo de Trabajo

### 1. Análisis de la Pantalla o Widget
- Verificar si la vista utiliza `AppTheme` en lugar de `Colors.blue` u otros colores genéricos *hardcodeados*.
- Comprobar que los textos utilicen estilos de `Theme.of(context).textTheme` adaptados a la jerarquía de la app.

### 2. Implementación de Componentes
- Construir widgets reutilizables con soporte de accesibilidad y contraste adecuado.
- Aplicar esquinas redondeadas (`BorderRadius.circular(12)`) y sombras sutiles según la guía.

### 3. Validación
- Ejecutar el análisis estático de Flutter para verificar ausencia de lints o errores de tipo.
```
