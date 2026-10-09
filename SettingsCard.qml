// The buddy's own settings card. Omarchy draws settings forms only for bar
// widgets, so the panel draws this one itself, next to the critter, inside
// its own layer window. Mouse only: the card never takes keyboard focus, so
// it can't steal typing from whatever you're working in. Free-text settings
// (the Ollama URL and model) stay on `omarchy-shell omabuddy set`; "ask me
// something" closes the card and opens the ask box, which does take focus.
//
// `host` is Buddy.qml's root. Every control writes through host.updateSetting,
// so the card and `set` land in the same shell.json entry.
import QtQuick
import qs.Commons
import qs.Ui
import "Buddies.js" as Buddies
import "Quips.js" as Quips

BorderSurface {
  id: card

  required property var host

  readonly property int gap: Style.spacing.lg
  readonly property int inner: Style.space(320)
  readonly property color dim: Qt.darker(Color.popups.text, 1.4)

  width: inner + contentLeftInset + contentRightInset
  height: content.implicitHeight + contentTopInset + contentBottomInset
  color: Color.popups.background
  borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Math.max(1, Style.space(2)))
  radius: Style.cornerRadius
  padding: Style.spacing.popupPadding

  // Pop in from the buddy's side.
  opacity: 0
  scale: 0.96
  transformOrigin: card.host.cardOrigin
  Component.onCompleted: { opacity = 1; scale = 1 }
  Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

  // Swallow clicks on the card's own empty space so they don't reach the
  // dismiss catcher underneath.
  MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

  // Close after a while with the pointer elsewhere.
  HoverHandler { id: cardHover }
  Timer {
    interval: 20000
    running: !cardHover.hovered
    onTriggered: card.host.closeSettings()
  }

  // A label with a switch on the right, one row per boolean setting.
  component SwitchRow: Item {
    id: switchRow
    required property string label
    required property bool checked
    signal toggled()
    width: card.inner
    height: Math.max(switchLabel.implicitHeight, switchControl.implicitHeight)
    Text {
      id: switchLabel
      anchors.left: parent.left
      anchors.right: switchControl.left
      anchors.rightMargin: card.gap
      anchors.verticalCenter: parent.verticalCenter
      text: switchRow.label
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    ToggleSwitch {
      id: switchControl
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      cursorRing: false
      trackHeight: Math.max(14, Math.round(Style.spacing.controlHeight * 0.5))
      checked: switchRow.checked
      onToggled: switchRow.toggled()
    }
  }

  component Caption: Text {
    textFormat: Text.PlainText
    color: card.dim
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    width: card.inner
  }

  Column {
    id: content
    x: card.contentLeftInset
    y: card.contentTopInset
    width: card.inner
    spacing: card.gap

    // ------------------------------------------------------------ header
    Item {
      width: card.inner
      height: Math.max(titleBlock.implicitHeight, closeButton.implicitHeight)
      Column {
        id: titleBlock
        anchors.left: parent.left
        anchors.right: closeButton.left
        anchors.rightMargin: card.gap
        spacing: Style.spacing.xs
        Text {
          text: "omabuddy"
          textFormat: Text.PlainText
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }
        Caption {
          width: parent.width
          text: "feeling " + card.host.mood + (card.host.moodReason === "forced" ? "" : " · " + card.host.moodReason)
          elide: Text.ElideRight
          wrapMode: Text.NoWrap
        }
      }
      Button {
        id: closeButton
        anchors.right: parent.right
        anchors.top: parent.top
        text: "×"
        onClicked: card.host.closeSettings()
      }
    }

    // ------------------------------------------------------------- buddy
    PanelSectionHeader { text: "buddy" }
    Row {
      id: tiles
      spacing: Style.spacing.md
      readonly property int tileWidth: Math.floor((card.inner - spacing * (Buddies.list.length - 1)) / Buddies.list.length)
      property string hoveredId: ""
      Repeater {
        model: Buddies.list
        delegate: BorderSurface {
          id: tile
          required property var modelData
          readonly property bool chosen: modelData.id === card.host.buddyId
          readonly property bool hot: tileMouse.containsMouse
          width: tiles.tileWidth
          height: Style.space(86)
          radius: Style.cornerRadius
          // Same state precedence as the shell's Button chips.
          color: hot ? Style.hoverFillFor(Color.popups.text, Color.accent)
            : chosen ? Style.selectedFillFor(Color.popups.text, Color.accent) : "transparent"
          borderSpec: Border.controlSpec(hot ? "hover-cursor" : "normal", Color.popups.text, Color.accent)

          Face {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, (parent.height - tileName.height - height) / 2)
            width: implicitWidth
            height: implicitHeight
            pixelSize: Style.space(5)
            buddy: tile.modelData.id
            eyes: tile.hot ? "◠    ◠" : card.host.faceSpec.eyes
            mouth: tile.hot ? "▽ " : card.host.faceSpec.mouth
            bob: tile.hot ? 500 : (tile.chosen ? card.host.faceSpec.bob : 0)
            fidget: tile.hot || tile.chosen
            color: tile.chosen || tile.hot ? card.host.roleColor(card.host.faceSpec.role) : card.dim
          }
          Text {
            id: tileName
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.spacing.sm
            text: tile.modelData.name
            textFormat: Text.PlainText
            color: tile.chosen ? Color.popups.text : card.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: tile.chosen
          }
          MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: tiles.hoveredId = containsMouse ? tile.modelData.id : (tiles.hoveredId === tile.modelData.id ? "" : tiles.hoveredId)
            onClicked: card.host.switchBuddy(tile.modelData.id)
          }
        }
      }
    }
    Caption { text: Buddies.byId(tiles.hoveredId || card.host.buddyId).blurb }

    // ------------------------------------------------------------- voice
    PanelSectionHeader { text: "voice" }
    ButtonGroup {
      id: toneGroup
      focusable: false
      spacing: Style.spacing.sm
      property string hoveredId: ""
      options: Quips.tones.map(function(t) { return { value: t.id, label: t.name } })
      value: card.host.tone
      onChanged: function(v) { card.host.sampleTone(v) }
      onHovered: function(i, h) { hoveredId = h ? Quips.tones[i].id : (hoveredId === Quips.tones[i].id ? "" : hoveredId) }
    }
    Caption { text: Quips.tone(toneGroup.hoveredId || card.host.tone).blurb }

    // ----------------------------------------------------------- chatter
    PanelSectionHeader { text: "chatter" }
    Item {
      width: card.inner
      height: Math.max(chatter.implicitHeight, muteRow.implicitHeight)
      ButtonGroup {
        id: chatter
        anchors.verticalCenter: parent.verticalCenter
        focusable: false
        spacing: Style.spacing.sm
        options: [{ value: "30", label: "rarely" }, { value: "12", label: "sometimes" }, { value: "5", label: "often" }]
        value: String(card.host.chattiness)
        onChanged: function(v) { card.host.updateSetting("chattiness", Number(v)) }
      }
      Row {
        id: muteRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.sm
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "mute"
          textFormat: Text.PlainText
          color: card.dim
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        ToggleSwitch {
          cursorRing: false
          trackHeight: Math.max(14, Math.round(Style.spacing.controlHeight * 0.5))
          checked: card.host.muted
          onToggled: card.host.updateSetting("muted", !card.host.muted)
        }
      }
    }

    // ------------------------------------------------------------- place
    PanelSectionHeader { text: "place" }
    Item {
      width: card.inner
      height: Math.max(sizeRow.implicitHeight, cornerGroup.implicitHeight)
      Row {
        id: sizeRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.sm
        Button { text: "−"; bordered: true; onClicked: card.host.nudgeSize(-2) }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(44)
          horizontalAlignment: Text.AlignHCenter
          text: (card.host.pendingSize > 0 ? card.host.pendingSize : card.host.size) + " px"
          textFormat: Text.PlainText
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
        Button { text: "+"; bordered: true; onClicked: card.host.nudgeSize(2) }
      }
      ButtonGroup {
        id: cornerGroup
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        focusable: false
        spacing: Style.spacing.xs
        options: [{ value: "top-left", label: "↖" }, { value: "top-right", label: "↗" },
                  { value: "bottom-left", label: "↙" }, { value: "bottom-right", label: "↘" }]
        value: card.host.corner
        onChanged: function(v) { card.host.updateSetting("corner", v) }
      }
    }

    // ------------------------------------------------------------- brain
    PanelSectionHeader { text: "brain" }
    Item {
      width: card.inner
      height: Math.max(brainGroup.implicitHeight, askButton.implicitHeight)
      ButtonGroup {
        id: brainGroup
        anchors.verticalCenter: parent.verticalCenter
        focusable: false
        spacing: Style.spacing.sm
        options: [{ value: "off", label: "canned lines" }, { value: "ollama", label: "ollama" }]
        value: card.host.llm === "ollama" ? "ollama" : "off"
        onChanged: function(v) { card.host.updateSetting("llm", v) }
      }
      Button {
        id: askButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        bordered: true
        text: "ask me something"
        onClicked: card.host.openAsk()
      }
    }
    Caption {
      text: card.host.llm === "ollama"
        ? "improvises with " + card.host.ollamaModel + " at " + card.host.ollamaUrl + ". change with omarchy-shell omabuddy set."
        : "only what's in Quips.js. nothing leaves the machine."
    }

    // ------------------------------------------------------------ senses
    PanelSectionHeader { text: "senses" }
    SwitchRow {
      label: "desktop: workspaces, new windows, fullscreen"
      checked: card.host.senseDesktop
      onToggled: card.host.updateSetting("senseDesktop", !card.host.senseDesktop)
    }
    SwitchRow {
      label: "devices: speaker, network, bluetooth"
      checked: card.host.senseDevices
      onToggled: card.host.updateSetting("senseDevices", !card.host.senseDevices)
    }
    SwitchRow {
      label: "music: what's playing"
      checked: card.host.senseMusic
      onToggled: card.host.updateSetting("senseMusic", !card.host.senseMusic)
    }
    Caption {
      text: card.host.senseMusic && card.host.llm === "ollama"
        ? "track and artist go to ollama with each line."
        : "off by default. each one only reads while it's on."
    }

    // ----------------------------------------------------------- preview
    // The speech bubble moves in here while the card is open, so a tone or
    // buddy you just picked can be heard right away.
    Rectangle {
      width: card.inner
      height: previewText.implicitHeight + Style.space(9) * 2
      radius: Style.space(8)
      bottomRightRadius: card.host.buddyOnRight ? Math.max(1, Style.space(2)) : radius
      bottomLeftRadius: card.host.buddyOnRight ? radius : Math.max(1, Style.space(2))
      color: Color.foreground
      opacity: card.host.bubbleOpen ? 1 : 0.55
      Behavior on opacity { NumberAnimation { duration: 180 } }
      Text {
        id: previewText
        x: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(12) * 2
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: card.host.line || "pick something. i'll say a word about it."
        color: Color.background
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.weight: Font.Medium
        lineHeight: 1.3
      }
    }
  }
}
