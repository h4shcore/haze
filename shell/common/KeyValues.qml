import QtQuick

// Wrapping grid of small "LABEL / value" tiles. Entries with an empty value are skipped.
Flow {
    id: root

    property var items: []      // [{ k, v }]
    readonly property var shown: items.filter(i => (i.v ?? "") !== "")

    visible: shown.length > 0
    spacing: 8

    Repeater {
        model: root.shown

        Rectangle {
            id: kv

            required property var modelData

            width: Math.min(root.width, Math.max(92, vcol.implicitWidth + 28))
            height: 46
            radius: 14
            color: Qt.alpha(Look.fg, 0.06)

            Column {
                id: vcol
                anchors.centerIn: parent
                spacing: 1

                Label {
                    text: kv.modelData.k.toUpperCase()
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1
                    color: Look.fgDim
                }
                Label {
                    text: kv.modelData.v
                    font.pixelSize: 12
                }
            }
        }
    }
}
