import QtQuick

// Pill-shaped single-line text field. Enter -> accepted, Esc -> escaped.
// `focusWhen` grabs the keyboard focus shortly after it turns true (lets a drawer finish opening first).
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder
    property bool password: false
    property bool focusWhen: false
    signal accepted
    signal escaped

    function focusInput() { input.forceActiveFocus(); }

    implicitWidth: 220
    implicitHeight: 38
    radius: height / 2
    color: Look.surfaceHiest
    border.width: input.activeFocus ? 2 : 0
    border.color: Look.primary

    onFocusWhenChanged: if (focusWhen) focusTimer.restart()
    Timer {
        id: focusTimer
        interval: 240
        onTriggered: input.forceActiveFocus()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }

    TextInput {
        id: input
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 16
            rightMargin: 16
        }
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        clip: true
        color: Look.fg
        selectionColor: Look.primary
        selectedTextColor: Look.primaryFg
        font.family: Look.font
        font.pixelSize: 13

        onAccepted: root.accepted()
        Keys.onEscapePressed: ev => {
            root.escaped();
            root.forceActiveFocus();   // keep focus inside the window so the next Esc still closes it
            ev.accepted = true;
        }

        Label {
            visible: input.text === ""
            text: root.placeholder
            color: Look.fgDim
        }
    }
}
