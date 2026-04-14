#!/bin/bash
# QuickShell Configuration Validation Script
# Checks for common configuration errors

echo "🔍 Validando configuración de QuickShell..."
echo ""

cd ~/.config/quickshell || exit 1

errors=0
warnings=0

# Check 1: Uppercase property names (ALL CAPS like MAX_CRASHES)
echo "1. Verificando nombres de propiedades..."
if grep -rE "property.*\s[A-Z_]+[A-Z_]+\s*:" --include="*.qml" . 2>/dev/null | grep -v "Qt\.\|Config\.\|Service\.\|Quickshell\." > /dev/null; then
    echo "   ❌ ERROR: Propiedades con nombres en MAYÚSCULAS (ALL_CAPS) encontradas"
    grep -rnE "property.*\s[A-Z_]+[A-Z_]+\s*:" --include="*.qml" . 2>/dev/null | grep -v "Qt\.\|Config\.\|Service\.\|Quickshell\." | head -5
    ((errors++))
else
    echo "   ✓ OK"
fi

# Check 2: Broken imports
echo "2. Verificando imports rotos..."
broken_imports=$(grep -r "import.*modules/" --include="*.qml" . 2>/dev/null | grep -v "modules/shell\|modules/tools\|modules/appearance\|modules/wallpaper" || true)
if [ -n "$broken_imports" ]; then
    echo "   ❌ ERROR: Imports a módulos no existentes"
    echo "$broken_imports" | head -5
    ((errors++))
else
    echo "   ✓ OK"
fi

# Check 3: Duplicate module directories
echo "3. Verificando módulos duplicados..."
duplicates=$(ls modules/ 2>/dev/null | grep -E "^(bar|calendar|clipboard|keybinds|launcher|notifications|osd|power|quickSettings|screenshot|systemMonitor)$" || true)
if [ -n "$duplicates" ]; then
    echo "   ⚠️  WARNING: Módulos duplicados encontrados en modules/"
    echo "   Debe usar solo: modules/shell/, modules/tools/, modules/appearance/"
    echo "$duplicates"
    ((warnings++))
else
    echo "   ✓ OK"
fi

# Check 4: Required scripts present
echo "4. Verificando scripts críticos..."
missing_scripts=()
scripts=(
    "scripts/ai/ai_chat.py"
    "scripts/agents/bluetooth-agent.py"
    "scripts/tools/copy-image-to-clipboard.sh"
)

for script in "${scripts[@]}"; do
    if [ ! -f "$script" ]; then
        missing_scripts+=("$script")
    fi
done

if [ ${#missing_scripts[@]} -gt 0 ]; then
    echo "   ❌ ERROR: Scripts faltantes:"
    printf '   - %s\n' "${missing_scripts[@]}"
    ((errors++))
else
    echo "   ✓ OK"
fi

# Check 5: Script permissions
echo "5. Verificando permisos de ejecución..."
non_executable=()
for script in scripts/tools/*.sh; do
    if [ -f "$script" ] && [ ! -x "$script" ]; then
        non_executable+=("$script")
    fi
done

if [ ${#non_executable[@]} -gt 0 ]; then
    echo "   ⚠️  WARNING: Scripts sin permisos de ejecución:"
    printf '   - %s\n' "${non_executable[@]}"
    echo "   Ejecutar: chmod +x ~/.config/quickshell/scripts/tools/*.sh"
    ((warnings++))
else
    echo "   ✓ OK"
fi

# Summary
echo ""
echo "════════════════════════════════════════"
if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    echo "✅ VALIDACIÓN EXITOSA"
    echo "La configuración está lista para usar."
    exit 0
elif [ $errors -eq 0 ]; then
    echo "⚠️  VALIDACIÓN CON ADVERTENCIAS"
    echo "Warnings: $warnings"
    echo "La configuración debería funcionar pero revisa los warnings."
    exit 0
else
    echo "❌ VALIDACIÓN FALLIDA"
    echo "Errores: $errors"
    echo "Warnings: $warnings"
    echo "Corrige los errores antes de reiniciar QuickShell."
    exit 1
fi
