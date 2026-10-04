# Estándares Oficiales de Habilidades (Skills) en Google Antigravity

Documentación de referencia basada en la especificación oficial de Google Antigravity (`https://antigravity.google/docs/skills`).

---

## 1. ¿Qué es una Habilidad (Skill)?

Una habilidad es un paquete modular y reutilizable de conocimiento y procedimientos que amplía las capacidades del agente de IA. Funciona como una "hoja de trucos" (*cheatsheet*) o manual operativo (*runbook*) para flujos de trabajo específicos, permitiendo al agente ejecutar tareas complejas con alta confiabilidad y sin sobrecargar la ventana de contexto.

Cada habilidad contiene:
- **Instrucciones:** Protocolos explícitos sobre cómo abordar una tarea concreta.
- **Mejores prácticas:** Convenciones, pautas de estilo y listas de verificación (*checklists*).
- **Scripts y recursos opcionales:** Herramientas ejecutables, plantillas o esquemas que el agente puede utilizar.

---

## 2. Ubicación y Ámbitos de Habilidades

Las habilidades se organizan según su alcance (*scope*):

| Ámbito | Ubicación | Uso |
|---|---|---|
| **Proyecto / Espacio de Trabajo (Workspace)** | `<workspace-root>/.agents/skills/<nombre-habilidad>/` *(o `.agent/skills/` por retrocompatibilidad)* | Específico del proyecto actual. Se versiona en Git para compartirlo con el equipo de desarrollo. |
| **Global (Toda la máquina)** | `~/.gemini/config/skills/<nombre-habilidad>/` *(en Windows: `C:\Users\<Usuario>\.gemini\config\skills\<nombre-habilidad>\`)* | Disponible en todos los proyectos y espacios de trabajo del usuario. |
| **Plugins** | `<plugin-root>/skills/<nombre-habilidad>/` | Habilidades empaquetadas como parte de un plugin distribuible. |

---

## 3. Anatomía de una Habilidad

Una habilidad es un directorio nombrado con la siguiente estructura:

```text
<nombre-habilidad>/
├── SKILL.md          # [OBLIGATORIO] Manifiesto principal de instrucciones y metadatos
├── references/       # [OPCIONAL] Documentación extensa, manuales o guías de referencia
├── resources/        # [OPCIONAL] Plantillas, esquemas de datos, configuraciones
├── examples/         # [OPCIONAL] Ejemplos de implementación o código de referencia
└── scripts/          # [OPCIONAL] Scripts auxiliares ejecutables (PowerShell, Bash, Python, etc.)
```

---

## 4. Manifiesto Principal (`SKILL.md`) y Frontmatter YAML

El archivo `SKILL.md` **debe** comenzar con un encabezado YAML delimitado por `---`:

```markdown
---
name: nombre-de-habilidad
description: >-
  Describe con precisión qué hace la habilidad y exactamente cuándo debe activarse.
  Escrito siempre en tercera persona con palabras clave relevantes.
---

# Título de la Habilidad

Instrucciones claras y paso a paso para el agente...
```

### Campos del Frontmatter YAML:

| Campo | Obligatorio | Tipo | Descripción |
|---|---|---|---|
| `name` | Recomendado / Opcional | `string` | Identificador único en minúsculas, con palabras separadas por guiones medios (kebab-case). Por defecto toma el nombre del directorio. |
| `description` | **Sí** | `string` | **El campo más crítico.** El agente lee esta descripción al inicio de cada conversación para decidir si activa la habilidad. Debe explicar con claridad **QUÉ** hace y **CUÁNDO** debe usarse, redactado en tercera persona con términos de activación. |

---

## 5. Principios Clave y Buenas Prácticas

### 1. Enfoque Único (Keep Skills Focused)
Cada habilidad debe resolver una sola responsabilidad con excelencia. No crear habilidades monstruosas como `desarrollo-completo`. En su lugar, dividir en habilidades específicas (ej. `auditoria-seguridad`, `migracion-db`, `estilos-flutter`).

### 2. Divulgación Progresiva (Progressive Disclosure)
- El archivo `SKILL.md` debe ser conciso, directo y enfocado en el flujo operativo.
- La documentación extensa, tablas masivas o manuales de referencia deben colocarse en `references/` y vincularse con enlaces Markdown relativos: `[Ver especificación completa](./references/api.md)`.
- El agente solo leerá estos subarchivos cuando los necesite, optimizando la ventana de contexto.

### 3. Scripts como Cajas Negras (Black Boxes)
- Si una habilidad incluye scripts auxiliares en `scripts/`, indícale al agente que consulte la ayuda (`--help`) o ejecute el script directamente, en lugar de parsear y leer todo el código fuente del script.
- Esto ahorra tokens y reduce errores de interpretación.

### 4. Árboles de Decisión (Decision Trees)
Para flujos que dependan de diferentes condiciones (ej. entorno de producción vs desarrollo, nuevo componente vs refactorización), incluye un árbol de decisión claro o una tabla condicional.

### 5. Pasos de Validación (Verification Steps)
Cada acción clave debe indicar cómo verificar que se completó con éxito (ej. comando de análisis estático, revisión de log, validación de salida).

### 6. No Duplicar Conocimiento General
No instruir al modelo sobre conceptos básicos de programación universal (qué es una variable, sintaxis básica de bucles). Enfocarse exclusivamente en los procedimientos, convenciones y especificidades del proyecto o flujo.

---

## 6. Mecanismo de Activación (Invocación)

1. **Invocación Autónoma:** El agente lee nombres y descripciones disponibles. Si el contexto del usuario coincide, carga automáticamente el `SKILL.md`.
2. **Invocación Manual (Comando Slash):** El usuario puede forzar la invocación escribiendo `/<nombre-de-habilidad>` en el panel de entrada (por ejemplo, `/creador-habilidades`).
