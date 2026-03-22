pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "."

JsonStore {
    id: root

    storePath: Quickshell.env("HOME") + "/.config/quickshell/data/state/ai-history.json"
    fallbackPaths: [Quickshell.env("HOME") + "/.config/quickshell/ai-history.json"]
    secureWrite: true
    logPrefix: "AiHistoryService"
}
