pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "."

JsonStore {
    id: root

    storePath: Quickshell.env("HOME") + "/.config/quickshell/data/private/secrets.json"
    fallbackPaths: [Quickshell.env("HOME") + "/.config/quickshell/secrets.json"]
    secureWrite: true
    logPrefix: "SecretsService"
}
