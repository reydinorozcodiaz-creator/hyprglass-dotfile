pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"
import "./pages/"

QsPopupWindow {
    id: root

    popupWidth: 400
    popupMaxHeight: 700
    anchorSide: "right"
    moduleName: "QuickSettings"
    contentImplicitHeight: pageStack.children[pageStack.currentIndex]?.implicitHeight ?? popupMaxHeight - 32

    // Named page indices to avoid magic numbers
    readonly property int pageDashboard: 0
    readonly property int pageWifi: 1
    readonly property int pageWifiPassword: 2
    readonly property int pageBluetooth: 3
    readonly property int pageNightLight: 4
    readonly property int pageTheme: 5
    readonly property int pageDnd: 6
    readonly property int pageAudio: 7

    Component.onCompleted: {
        root.visible = false;
        pageStack.currentIndex = pageDashboard;
    }

    onClosing: pageStack.currentIndex = pageDashboard

    StackLayout {
        id: pageStack
        anchors.fill: parent
        currentIndex: 0

        // ==========================
        // PAGE 0: DASHBOARD
        // ==========================
        DashboardPage {
            onCloseWindow: root.closeWindow()
            onNavigateTo: page => pageStack.currentIndex = page
        }

        // ==========================
        // PAGE 1: WI-FI
        // ==========================
        WifiPage {
            onBackRequested: pageStack.currentIndex = root.pageDashboard
            onPasswordRequested: ssid => {
                wifiPasswordPage.targetSsid = ssid;
                pageStack.currentIndex = root.pageWifiPassword;
            }
        }

        // ==========================
        // PAGE 2: WI-FI PASSWORD
        // ==========================
        WifiPasswordPage {
            id: wifiPasswordPage
            onCancelled: pageStack.currentIndex = root.pageWifi
            onConnectClicked: password => {
                NetworkService.connect(targetSsid, password);
                pageStack.currentIndex = root.pageWifi;
            }
        }

        // ==========================
        // PAGE 3: BLUETOOTH
        // ==========================
        BluetoothPage {
            onBackRequested: pageStack.currentIndex = root.pageDashboard
        }

        // ==========================
        // PAGE 4: NIGHT LIGHT
        // ==========================
        NightLightPage {
            onBackRequested: pageStack.currentIndex = root.pageDashboard
        }

        // ==========================
        // PAGE 5: THEME
        // ==========================
        ThemePage {
            onBackRequested: pageStack.currentIndex = root.pageDashboard
        }

        // ==========================
        // PAGE 6: DO NOT DISTURB
        // ==========================
        DndPage {
            onBackRequested: pageStack.currentIndex = root.pageDashboard
        }

        // ==========================
        // PAGE 7: AUDIO
        // ==========================
        AudioPage {
            onBackRequested: pageStack.currentIndex = root.pageDashboard
        }
    }
}
