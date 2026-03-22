pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root

    signal backRequested

    readonly property var currentProfileInfo: PerformanceProfileService.profileById(PerformanceProfileService.activeProfile)

    Layout.fillWidth: true
    implicitHeight: flickable.contentHeight

    Component.onCompleted: PerformanceProfileService.refresh()

    Flickable {
        id: flickable
        anchors.fill: parent
        contentHeight: main.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: main
            width: flickable.width
            spacing: 12

            PageHeader {
                icon: PerformanceProfileService.systemIcon
                iconColor: PerformanceProfileService.isPerformanceBiased ? Config.warningColor : Config.accentColor
                title: "Performance"
                onBackClicked: root.backRequested()

                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: modeBadge.implicitWidth + 16
                    radius: Config.radius
                    color: Qt.alpha(Config.accentColor, 0.15)
                    border.width: 1
                    border.color: Qt.alpha(Config.accentColor, 0.3)

                    Text {
                        id: modeBadge
                        anchors.centerIn: parent
                        text: PerformanceProfileService.profileMode === "auto" ? "Auto" : "Manual"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: Config.accentColor
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                implicitHeight: currentProfileContent.implicitHeight + 20
                radius: Config.radiusLarge
                color: Config.surface0Color
                border.width: 1
                border.color: Qt.alpha(Config.textColor, 0.10)

                ColumnLayout {
                    id: currentProfileContent
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Text {
                        text: "Current profile"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: Config.subtextColor
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: PerformanceProfileService.systemIcon
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIcon
                            color: Config.textColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: PerformanceProfileService.profileLabel
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeNormal
                                font.bold: true
                                color: Config.textColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: PerformanceProfileService.switching
                                    ? "Applying profile..."
                                    : ((root.currentProfileInfo && root.currentProfileInfo.description) ? root.currentProfileInfo.description : PerformanceProfileService.modeLabel)
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.subtextColor
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            Text {
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                text: "Quick picks"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.subtextColor
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: PerformanceProfileService.quickProfiles

                    delegate: Rectangle {
                        id: quickProfileButton
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 42
                        radius: Config.radius

                        readonly property bool isActive: PerformanceProfileService.activeProfile === modelData.id

                        color: isActive ? Config.accentColor : (quickMouse.containsMouse ? Config.surface1Color : Config.surface0Color)
                        border.width: 1
                        border.color: isActive ? Config.accentColor : Qt.alpha(Config.textColor, 0.08)

                        Behavior on color {
                            ColorAnimation { duration: Config.animDurationShort }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: PerformanceProfileService.formatProfileName(quickProfileButton.modelData.id)
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: quickProfileButton.isActive
                            color: quickProfileButton.isActive ? Config.textReverseColor : Config.textColor
                        }

                        MouseArea {
                            id: quickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !PerformanceProfileService.switching
                            onClicked: PerformanceProfileService.setProfile(quickProfileButton.modelData.id)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Config.surface1Color
            }

            Text {
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                text: "All profiles"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.subtextColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 10
                spacing: 8

                Repeater {
                    model: PerformanceProfileService.availableProfiles

                    delegate: Rectangle {
                        id: profileCard
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: profileContent.implicitHeight + 18
                        radius: Config.radiusLarge

                        readonly property bool isActive: PerformanceProfileService.activeProfile === modelData.id

                        color: isActive ? Qt.alpha(Config.accentColor, 0.16) : (profileMouse.containsMouse ? Config.surface1Color : Config.surface0Color)
                        border.width: 1
                        border.color: isActive ? Qt.alpha(Config.accentColor, 0.55) : Qt.alpha(Config.textColor, 0.08)

                        Behavior on color {
                            ColorAnimation { duration: Config.animDurationShort }
                        }

                        RowLayout {
                            id: profileContent
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 10

                            Text {
                                Layout.alignment: Qt.AlignTop
                                text: PerformanceProfileService.iconForProfile(profileCard.modelData.id)
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeIcon
                                color: profileCard.isActive ? Config.accentColor : Config.textColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    text: PerformanceProfileService.formatProfileName(profileCard.modelData.id)
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeNormal
                                    font.bold: true
                                    color: Config.textColor
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: profileCard.modelData.description || profileCard.modelData.id
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    color: Config.subtextColor
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                visible: profileCard.isActive
                                text: "󰄬"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeIcon
                                color: Config.accentColor
                            }
                        }

                        MouseArea {
                            id: profileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !PerformanceProfileService.switching
                            onClicked: PerformanceProfileService.setProfile(profileCard.modelData.id)
                        }
                    }
                }

                Text {
                    visible: !PerformanceProfileService.loading && PerformanceProfileService.availableProfiles.length === 0
                    Layout.fillWidth: true
                    text: PerformanceProfileService.available ? "No profiles reported by TuneD." : "TuneD is unavailable."
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
