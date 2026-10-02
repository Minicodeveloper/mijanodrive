<#
.SYNOPSIS
    Inicializa la estructura de una nueva habilidad (skill) para Google Antigravity.
.DESCRIPTION
    Crea el directorio de la habilidad, el archivo SKILL.md con frontmatter YAML válido
    y las subcarpetas recomendadas (references, resources, scripts, examples).
.PARAMETER Name
    Identificador único de la habilidad en kebab-case (ej. auditoria-codigo).
.PARAMETER Description
    Descripción en tercera persona indicando qué hace y cuándo debe activarse.
.PARAMETER Scope
    Ámbito de la habilidad: 'workspace' (por defecto) o 'global'.
.EXAMPLE
    .\init_skill.ps1 -Name "crear-componentes-ui" -Description "Crea widgets Flutter personalizados siguiendo AppTheme. Usar al crear vistas o botones." -Scope "workspace"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^[a-z0-9]+(-[a-z0-9]+)*$')]
    [string]$Name,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Description,

    [Parameter(Mandatory = $false)]
    [ValidateSet('workspace', 'global')]
    [string]$Scope = 'workspace'
)

$ErrorActionPreference = 'Stop'

# Determinar directorio raíz según el ámbito
if ($Scope -eq 'workspace') {
    # Buscar raíz del proyecto con git o directorio actual
    $workspaceRoot = Get-Location
    $targetDir = Join-Path $workspaceRoot ".agents\skills\$Name"
} else {
    $userProfile = [System.Environment]::GetFolderPath('UserProfile')
    $targetDir = Join-Path $userProfile ".gemini\config\skills\$Name"
}

if (Test-Path $targetDir) {
    Write-Error "El directorio de la habilidad ya existe: $targetDir"
}

Write-Host "Creando estructura para habilidad '$Name' en [$Scope]..." -ForegroundColor Cyan

# Crear carpetas estándar
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $targetDir "references") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $targetDir "resources") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $targetDir "examples") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $targetDir "scripts") -Force | Out-Null

# Generar contenido inicial de SKILL.md
$skillContent = @"
---
name: $Name
description: >-
  $Description
---

# $Name

Describe aquí el propósito, rol y alcance principal de la habilidad.

---

## Criterios de Decisión / Rutas

- **Caso 1:** Acción a tomar si aplica la condición A.
- **Caso 2:** Acción a tomar si aplica la condición B.

---

## Procedimiento Paso a Paso

### 1. Preparación e Inspección
1. Revisar los requisitos y archivos involucrados.

### 2. Ejecución
1. Aplicar los pasos necesarios siguiendo las buenas prácticas.

### 3. Verificación
1. Validar que los resultados sean correctos y libres de errores.

---

## Referencias
- [Documentación Adicional](./references/README.md)
"@

$skillFilePath = Join-Path $targetDir "SKILL.md"
[System.IO.File]::WriteAllText($skillFilePath, $skillContent, [System.Text.Encoding]::UTF8)

# Crear README en references
$refContent = "# Referencias para $Name`n`nDocumentación detallada complementaria."
[System.IO.File]::WriteAllText((Join-Path $targetDir "references\README.md"), $refContent, [System.Text.Encoding]::UTF8)

Write-Host "¡Habilidad creada con éxito en:" -ForegroundColor Green
Write-Host "  $skillFilePath" -ForegroundColor Yellow
Write-Host "Puedes invocarla escribiendo: /$Name" -ForegroundColor Cyan
