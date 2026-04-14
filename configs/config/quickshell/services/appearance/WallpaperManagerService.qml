pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// ============================================================================
// WallpaperManagerService — Puente entre Quickshell y AleatoryWall.sh
//
// Responsabilidades:
//   · apply(path)  → AleatoryWall.sh --file <path>  (swww + lock sync + pywal + state.json)
//   · next()       → AleatoryWall.sh --once          (avanza la queue anti-repetición)
//   · Sincroniza currentWallpaper leyendo .current-wallpaper (escrito por el script)
//   · pywalEnabled se persiste en state.json como "wallpaper.pywal"
//
// Reglas de diseño:
//   · NUNCA llama a swww directamente — eso es responsabilidad del script bash.
//   · NUNCA escribe .current-wallpaper directamente — lo hace el script.
//   · El daemon de AleatoryWall no se toca: sigue con su ciclo de 60 min.
// ============================================================================

Singleton {
    id: root

    signal applyFinished(bool ok, string requestedPath, string previousPath, string errorMessage)

    // ========================================================================
    // PATHS
    // ========================================================================

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/tools/AleatoryWall.sh"
    readonly property string currentWallFile: Quickshell.env("HOME") + "/.config/hypr/logs/.current-wallpaper"
    property string currentWallWatchPath: ""

    // ========================================================================
    // ESTADO PÚBLICO
    // ========================================================================

    // Wallpaper activo según .current-wallpaper (fuente de verdad del script)
    property string currentWallpaper: ""
    property string pendingWallpaper: ""
    property string previousWallpaper: ""

    // true mientras alguna operación apply/next está en curso
    property bool busy: false

    // (Removed daemonRunning property)

    // Integración con pywal (persistido en state.json)
    property bool pywalEnabled: StateService.get("wallpaper.pywal", false)

    // ========================================================================
    // INICIALIZACIÓN
    // ========================================================================

    Component.onCompleted: {
        root.currentWallpaper = StateService.get("wallpaper.current", "");
        _probeCurrentWallFile.running = true;
    }

    // Sincronizar pywalEnabled cuando StateService recarga
    Connections {
        target: StateService
        function onStateLoaded() {
            root.pywalEnabled = StateService.get("wallpaper.pywal", false);
            root.autoRotate = StateService.get("wallpaper.autoRotate", true);
            root.autoRotateInterval = StateService.get("wallpaper.autoRotateInterval", 3600000);
        }
    }

    // Observar .current-wallpaper: si AleatoryWall lo cambia (ciclo horario),
    // Quickshell se entera automáticamente sin polling.
    FileView {
        id: _wallWatcher
        path: root.currentWallWatchPath
        watchChanges: true
        onFileChanged: _readCurrentWall.running = true
    }

    // Check daemon logic has been removed since AleatoryWall is no longer a daemon
    
    // ========================================================================
    // AUTO ROTATION
    // ========================================================================
    
    property bool autoRotate: StateService.get("wallpaper.autoRotate", true)
    property int autoRotateInterval: StateService.get("wallpaper.autoRotateInterval", 3600000) // 1 Hour

    Timer {
        id: rotationTimer
        interval: root.autoRotateInterval
        running: root.autoRotate
        repeat: true
        onTriggered: {
            console.log("[WallpaperManager] Auto-rotating wallpaper (interval hit)");
            root.next();
        }
    }

    // ========================================================================
    // API PÚBLICA
    // ========================================================================

    // Aplica un wallpaper concreto delegando en AleatoryWall.sh.
    // AleatoryWall se encarga de: swww, .lock-wallpaper, .current-wallpaper,
    // state.json y pywal (si está habilitado).
    function apply(path) {
        if (busy) {
            console.warn("[WallpaperManager] apply() ignorado: operación en curso");
            return;
        }
        previousWallpaper = currentWallpaper;
        pendingWallpaper = path;
        const args = ["bash", scriptPath, "--file", path];
        if (pywalEnabled) args.push("--pywal");
        _applyProc.command = args;
        _applyProc.running = true;
        busy = true;

        // Actualización optimista para que la UI responda de inmediato
        currentWallpaper = path;
    }

    // Avanza un paso en la queue de AleatoryWall (respeta anti-repetición).
    // Si el daemon está corriendo, el propio script detecta que hay una instancia
    // y simplemente hace el cambio (ver lógica "other_pid" en AleatoryWall.sh).
    function next() {
        if (busy) return;
        const args = ["bash", scriptPath, "--once"];
        if (pywalEnabled) args.push("--pywal");
        _nextProc.command = args;
        _nextProc.running = true;
        busy = true;
    }

    // Activa/desactiva pywal y persiste la preferencia
    function togglePywal() {
        pywalEnabled = !pywalEnabled;
        StateService.set("wallpaper.pywal", pywalEnabled);
    }

    // ========================================================================
    // PROCESOS INTERNOS
    // ========================================================================

    Process {
        id: _probeCurrentWallFile
        command: ["test", "-f", root.currentWallFile]

        onExited: exitCode => {
            const exists = exitCode === 0;
            root.currentWallWatchPath = exists ? root.currentWallFile : "";
            if (exists)
                _readCurrentWall.running = true;
        }
    }

    Process {
        id: _applyProc

        onExited: (exitCode) => {
            root.busy = false;
            if (exitCode === 0) {
                _probeCurrentWallFile.running = true;
                console.log("[WallpaperManager] apply() completado");
                root.applyFinished(true, root.pendingWallpaper, root.previousWallpaper, "");
            } else {
                console.error("[WallpaperManager] AleatoryWall --file falló, código:", exitCode);
                root.currentWallpaper = root.previousWallpaper;
                root.applyFinished(false, root.pendingWallpaper, root.previousWallpaper, "No se pudo aplicar el wallpaper seleccionado.");
            }
            root.pendingWallpaper = "";
        }
    }

    Process {
        id: _nextProc

        onExited: (exitCode) => {
            root.busy = false;
            if (exitCode === 0)
                _probeCurrentWallFile.running = true;
            else
                console.error("[WallpaperManager] AleatoryWall --once falló, código:", exitCode);
        }
    }

    // Lee el archivo .current-wallpaper que escribe AleatoryWall.sh
    Process {
        id: _readCurrentWall
        command: ["cat", root.currentWallFile]

        property string _buf: ""

        stdout: SplitParser {
            onRead: data => _readCurrentWall._buf += data
        }

        onStarted: _buf = ""

        onExited: (exitCode) => {
            const val = _buf.trim();
            if (exitCode === 0 && val)
                root.currentWallpaper = val;
            _buf = "";
        }
    }


}
