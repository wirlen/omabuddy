// A one-line text box beside the critter for asking it something. Opened by
// `omarchy-shell omabuddy listen` (bind it to a key) or the settings card.
// While it is open the buddy's window takes keyboard focus (see Buddy.qml);
// Enter asks, Esc or a click anywhere else closes it, and so does half a
// minute without typing.
//
// `host` is Buddy.qml's root. The field stops at host.askMaxLength
// characters and host.ask() clips again, so nothing longer reaches Ollama.
import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: box

  required property var host
  readonly property int inner: Style.space(300)

  width: inner + contentLeftInset + contentRightInset
  height: content.implicitHeight + contentTopInset + contentBottomInset
  color: Color.popups.background
  borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Math.max(1, Style.space(2)))
  radius: Style.cornerRadius
  padding: Style.spacing.popupPadding

  opacity: 0
  scale: 0.96
  transformOrigin: box.host.cardOrigin
  Component.onCompleted: { opacity = 1; scale = 1; Qt.callLater(function() { field.forceActiveFocus() }) }
  Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

  // Keep clicks on the box away from the dismiss catcher underneath.
  MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: field.forceActiveFocus() }

  Timer { id: idle; interval: 30000; running: true; onTriggered: box.host.closeAsk() }

  Column {
    id: content
    x: box.contentLeftInset
    y: box.contentTopInset
    width: box.inner
    spacing: Style.spacing.sm

    Text {
      width: parent.width
      text: box.host.llm === "ollama" ? "ask the " + box.host.buddyId + " something" : "ollama is off: you'll get a canned reply"
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: Qt.darker(Color.popups.text, 1.4)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    TextField {
      id: field
      width: parent.width
      maximumLength: box.host.askMaxLength
      placeholderText: "say something…"
      onTextChanged: idle.restart()
      // Ask first: closing unloads this box, and with it `box`.
      onAccepted: {
        const host = box.host, said = text
        host.ask(said)
        host.closeAsk()
      }
      Keys.onEscapePressed: box.host.closeAsk()
    }
  }
}
