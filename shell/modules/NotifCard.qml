import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.services

// entry = an Entry from services/Notifs.qml
Rectangle {
    id: root

    required property var entry
    readonly property var n: entry?.notif ?? null
    readonly property string src: !n ? "" : ((n.image ?? "") !== "" ? n.image : ((n.appIcon ?? "") !== "" ? (n.appIcon.startsWith("/") ? "file://" + n.appIcon : Quickshell.iconPath(n.appIcon, true)) : ""))

    readonly property var actions: (n?.actions ?? []).filter(a => a.identifier !== "inline-reply")
    readonly property bool canReply: n?.hasInlineReply ?? false
    readonly property bool replyOpen: Notifs.replying === entry

    function sendReply() {
        const t = replyField.text.trim();
        if (t === "") return;
        n.sendInlineReply(t);
        replyField.text = "";
        Notifs.replying = null;
    }

    implicitHeight: col.implicitHeight + 24
    radius: 20
    color: Look.surfaceHi
    border.width: entry?.critical ? 1 : 0
    border.color: Look.error

    // left click: tuck popup away into the tray, right click: dismiss
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton) root.n?.dismiss();
            else if (root.entry) root.entry.popup = false;
        }
    }

    ColumnLayout {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ClippingRectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignTop
                radius: 12
                color: Look.surfaceHiest

                Image {
                    id: img
                    anchors.fill: parent
                    source: root.src
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                InkIcon {
                    anchors.centerIn: parent
                    visible: img.status !== Image.Ready
                    text: "\uf0f3"
                    pixelSize: 16
                    box: 28
                    color: Look.fgDim
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    text: root.n?.appName ?? ""
                    color: Look.fgDim
                    font.pixelSize: 11
                }
                Label {
                    Layout.fillWidth: true
                    text: root.n?.summary ?? ""
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.n?.body ?? ""
                    textFormat: Text.StyledText
                    color: Look.fgDim
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 0

                IconButton {
                    visible: (root.n?.appName ?? "") !== ""
                    size: 28
                    glyph: "\uf1f6"
                    primary: Notifs.isMuted(root.n?.appName)
                    onClicked: {
                        Notifs.toggleMute(root.n.appName);
                        if (Notifs.isMuted(root.n.appName) && root.entry) root.entry.popup = false;
                    }
                }
                IconButton {
                    size: 28
                    glyph: "\uf00d"
                    onClicked: root.n?.dismiss()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.actions.length > 0 || root.canReply
            spacing: 6

            Rectangle {
                visible: root.canReply
                implicitWidth: replyLbl.implicitWidth + 24
                implicitHeight: 28
                radius: 14
                color: root.replyOpen ? Look.primary : rm.containsMouse ? Look.secondaryContainer : Look.surfaceHiest
                Behavior on color { ColorAnimation { duration: 150 } }

                Label {
                    id: replyLbl
                    anchors.centerIn: parent
                    text: "Reply"
                    font.pixelSize: 12
                    color: root.replyOpen ? Look.primaryFg : Look.fg
                }
                MouseArea {
                    id: rm
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (root.replyOpen) Notifs.replying = null;
                        else {
                            if (root.entry) root.entry.popup = true;
                            Notifs.replying = root.entry;
                        }
                    }
                }
            }

            Repeater {
                model: root.actions

                Rectangle {
                    id: btn
                    required property var modelData
                    implicitWidth: lbl.implicitWidth + 24
                    implicitHeight: 28
                    radius: 14
                    color: bm.containsMouse ? Look.secondaryContainer : Look.surfaceHiest
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Label {
                        id: lbl
                        anchors.centerIn: parent
                        text: btn.modelData.text
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: bm
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: btn.modelData.invoke()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.canReply && root.replyOpen
            spacing: 6

            Field {
                id: replyField
                Layout.fillWidth: true
                implicitHeight: 34
                placeholder: root.n?.inlineReplyPlaceholder || "Write a reply"
                focusWhen: root.replyOpen
                onAccepted: root.sendReply()
                onEscaped: {
                    text = "";
                    Notifs.replying = null;
                }
            }
            IconButton {
                size: 34
                glyph: "\uf061"
                primary: replyField.text.trim() !== ""
                onClicked: root.sendReply()
            }
        }
    }
}
