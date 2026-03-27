# Copilot Workspace Instructions

## Propósito

Estas instrucciones definen convenciones, flujos de trabajo y recomendaciones para agentes de IA y desarrolladores que colaboran en este workspace, centrado en la configuración, personalización y automatización de entornos Hyprland, scripts y herramientas asociadas.

## Principios

- **Link, no dupliques**: Si existe documentación relevante (README, scripts, ejemplos), enlaza en vez de copiar contenido.
- **Automatización segura**: Prefiere scripts idempotentes y comandos que no alteren el sistema de forma irreversible sin confirmación.
- **Modularidad**: Mantén scripts y configuraciones divididos por propósito (ej: autostart, temas, reglas de ventanas).
- **Compatibilidad**: Prioriza soluciones compatibles con Linux y Wayland.
- **Documenta lo esencial**: Si un script requiere variables de entorno, dependencias externas o pasos manuales, documenta en comentarios o README.

## Flujos de trabajo recomendados

- **Personalización**: Realiza cambios en archivos dentro de `config/` para ajustes de color, variables, monitores y reglas.
- **Automatización**: Usa scripts en `scripts/` para tareas recurrentes (ej: logs, mantenimiento, transcripción de audio).
- **Temas y Rofi**: Gestiona temas y menús en la carpeta `rofi/` y sus subdirectorios.
- **Transcripción de audio**: Para usar whisper.cpp, sigue los pasos de compilación y uso descritos en los README de `scripts/system/transcribirAudio/`.

## Ejemplo de prompts

- "Agrega un nuevo atajo de teclado para lanzar rofi en modo drun."
- "Crea un script para cambiar el fondo de pantalla aleatoriamente."
- "Documenta cómo compilar whisper.cpp en este entorno."
- "Sugiere una convención para nombrar scripts de mantenimiento."

## Áreas de aplicación

- Configuración de Hyprland y Hypridle
- Automatización de tareas con scripts Bash
- Integración y personalización de Rofi
- Uso y extensión de whisper.cpp para transcripción

## Notas

- Si se requiere una instrucción específica para un archivo o carpeta, crea un archivo `.instructions.md` en la ruta correspondiente.
- Para flujos avanzados, considera definir hooks o agentes personalizados según la guía de agent-customization.
