pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "."

JsonStore {
    id: root

    storePath: Quickshell.env("HOME") + "/.config/quickshell/data/cache/ai-cache.json"
    fallbackPaths: [Quickshell.env("HOME") + "/.config/quickshell/ai-cache.json"]
    secureWrite: true
    logPrefix: "AiCacheService"
}
