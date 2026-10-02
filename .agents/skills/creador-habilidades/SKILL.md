---
name: creador-habilidades
description: Diseña, estructura y crea nuevas habilidades (skills) estándar para Google Antigravity en idioma español. Úsalo cuando el usuario solicite crear, generar, diseñar, estructurar o documentar una nueva habilidad (skill), o cuando se necesite empaquetar un procedimiento, flujo de trabajo o runbook recurrente para el agente.
---

# Creador de Habilidades para Google Antigravity

Esta habilidad guía al agente para actuar como un **Arquitecto de Habilidades (Skill Creator)** en Google Antigravity, creando paquetes modulares de conocimiento, procedimientos y herramientas según las especificaciones oficiales de la plataforma ([antigravity.google/docs/skills](https://antigravity.google/docs/skills)).

---

## Árbol de Decisión: Determinación del Ámbito y Complejidad

Antes de escribir código o documentación, evalúa los siguientes criterios:

```
¿La habilidad es exclusiva de este proyecto?
 ├── SÍ  ──> Ámbito: Workspace (`.agents/skills/<nombre>/`)
 └── NO  ──> Ámbito: Global (`~/.gemini/config/skills/<nombre>/`)

¿Qué nivel de complejidad requiere el procedimiento?
 ├── Simple (instrucción directa en un solo archivo)
 │    └── Crear únicamente `SKILL.md`
 ├── Con documentación extensa o guías de referencia
 │    └── `SKILL.md` + subcarpeta `references/` (Divulgación Progresiva)
 ├── Con plantillas, esquemas JSON o configuraciones
 │    └── `SKILL.md` + subcarpetas `resources/` o `examples/`
 └── Con comandos automatizados repetitivos
      └── `SKILL.md` + subcarpeta `scripts/` (tratados como cajas negras)
```

---

## Flujo de Trabajo para Crear una Nueva Habilidad

Sigue estrictamente las siguientes 4 fases en orden:

### Fase 1: Descubrimiento y Especificación de Requisitos
1. **Identificar la responsabilidad única:**
   - La habilidad debe resolver **un solo problema bien** (ejemplo: `auditoria-flutter`, `migracion-db`, `crear-tests-unitarios`).
   - Evitar habilidades genéricas o multitarea.
2. **Definir el nombre identificador (`name`):**
   - Debe ser en minúsculas con palabras separadas por guiones medios (`kebab-case`).
   - Ejemplo: `crear-widget-ui`, `despliegue-staging`.
3. **Redactar la descripción (`description`):**
   - **Regla crítica:** El agente lee este campo para decidir si activa la habilidad.
   - Redactar siempre en **tercera persona**.
   - Incluir **qué** hace y **cuándo** debe usarse con palabras clave de activación que el usuario suele emplear en sus prompts.

### Fase 2: Andamiaje de la Estructura de Directorios
Puedes usar el script auxiliar incluido o crear la estructura manualmente:

- **Vía script auxiliar:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File .agents/skills/creador-habilidades/scripts/init_skill.ps1 -Name "<nombre-habilidad>" -Description "<descripcion>" -Scope "workspace"
  ```
- **Vía manual:**
  Crear el directorio `.agents/skills/<nombre-habilidad>/` con su archivo principal `SKILL.md` y las subcarpetas necesarias (`references/`, `resources/`, `examples/`, `scripts/`).

### Fase 3: Redacción del Contenido de `SKILL.md`
Utiliza como base la [Plantilla de SKILL.md](./resources/plantilla_skill.md):

1. **Encabezado YAML Frontmatter:**
   ```yaml
   ---
   name: nombre-de-la-habilidad
   description: >-
     Acción en tercera persona indicando el objetivo y casos de activación.
   ---
   ```
2. **Propósito y Rol del Agente:**
   - Define el rol que adopta el agente al activarse (ej. "Actúa como revisor de accesibilidad").
3. **Criterios de Selección y Árbol de Decisión:**
   - Explicar las ramificaciones lógicas si el procedimiento varía según condiciones del entorno o peticiones del usuario.
4. **Instrucciones Paso a Paso:**
   - Paso 1: Inspección y lectura de archivos relevantes.
   - Paso 2: Procedimiento de ejecución claro y sin ambigüedades.
   - Paso 3: **Paso de validación obligatorio** (cómo comprobar que la tarea tuvo éxito mediante tests, lints o verificación de logs).
5. **Aplicación de Divulgación Progresiva:**
   - Mantén `SKILL.md` conciso. Mueve textos largos o tablas a archivos dentro de `references/` y enlázalos usando Markdown relativo: `[Detalles de la API](./references/api.md)`.
6. **Scripts como Cajas Negras:**
   - Si creas scripts en `scripts/`, documenta cómo ejecutarlos con `--help` o parámetros, sin forzar al agente a leer todo su código fuente.

### Fase 4: Validación y Prueba de la Habilidad
1. **Comprobar Frontmatter:** Verificar que el YAML comience en la línea 1 y no tenga errores de indentación.
2. **Comprobar Rutas Relativas:** Asegurarse de que todos los hipervínculos a `./references/` o `./resources/` apunten a archivos existentes.
3. **Confirmar Invocación:**
   - Verificar que esté disponible en `.agents/skills/<nombre-habilidad>/SKILL.md`.
   - Recordar al usuario que puede usarla tanto por detección contextual como manualmente mediante el comando slash `/<nombre-habilidad>`.

---

## Buenas Prácticas y Reglas de Oro

1. **Sin Duplicación de Habilidades Generales:** No expliques cómo programar en general ni reescribas la documentación oficial de un lenguaje. Céntrate en las normas y peculiaridades del proyecto o flujo.
2. **Claridad en Español:** Toda la documentación para el usuario y las explicaciones de la habilidad deben mantenerse en español técnico, claro y profesional.
3. **Verificación Proactiva:** Diseña las habilidades para que el agente verifique sus cambios antes de dar por terminada la tarea.

---

## Recursos de Referencia

- [Estándares Oficiales de Antigravity](./references/estandares_antigravity.md) - Especificación completa de Antigravity Skills.
- [Plantilla Lista para Nuevas Habilidades](./resources/plantilla_skill.md) - Estructura base para `SKILL.md`.
- [Ejemplo Práctico de Habilidad](./examples/ejemplo_skill.md) - Caso de estudio para Flutter.
- [Script de Andamiaje](./scripts/init_skill.ps1) - Utilidad PowerShell para automatizar la creación.
