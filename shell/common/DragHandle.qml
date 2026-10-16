import QtQuick

// Invisible drag strip for floating windows. Reports movement in `reference` coordinates
// (use the window's contentItem), so it stays steady while the thing under it moves.
//   moved(dx, dy) · dropped() when released · reset() on double-click
MouseArea {
    id: root

    property Item reference
    property real px: 0
    property real py: 0

    signal moved(real dx, real dy)
    signal dropped
    signal reset

    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    preventStealing: true

    onPressed: m => {
        const p = mapToItem(reference, m.x, m.y);
        px = p.x;
        py = p.y;
    }
    onPositionChanged: m => {
        if (!pressed) return;
        const p = mapToItem(reference, m.x, m.y);
        moved(p.x - px, p.y - py);
        px = p.x;
        py = p.y;
    }
    onReleased: dropped()
    onDoubleClicked: reset()
}
