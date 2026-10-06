import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import "../menu/MenuModel.js" as MenuModel

Item {
  id: root
  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property string view: "entries"
  property bool closingFromHost: false
  property string query: ""
  property var menuItems: ({})
  property var defaultEntries: []
  property var userEntries: []
  property var itemOrder: []
  property var settings: ({hidden:{}, globalUnhide:false, notifications:true, reviews:true})
  property var historyData: ({events:[],pending:[]})
  property var rows: []
  property int confirmStage: 0
  property string confirmId: ""

  function open(payloadJson) {
    try {
      var payload = JSON.parse(payloadJson || "{}")
      view = payload.view === "changes" ? "changes" : "entries"
    } catch (e) { view = "entries" }
    window.visible = true
    settingsFile.reload()
    historyProc.running = true
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  function hideSelf() {
    if (shell && typeof shell.hide === "function") shell.hide("omarchy.menu-settings")
    else window.visible = false
  }

  function hasHiddenAncestor(id) {
    var entry = menuItems[id]
    while (entry && entry.id !== "root") {
      if (settings.hidden && settings.hidden[entry.id]) return true
      entry = menuItems[entry.parent]
    }
    return false
  }

  function refreshRows() {
    rows = MenuModel.visibilityRows(menuItems, itemOrder, query)
  }

  function setHidden(id, hidden) {
    settingsProc.command = ["omarchy-menu-visibility", "set-hidden", id, hidden ? "true" : "false"]
    settingsProc.running = true
  }

  function setOption(name, value) {
    settingsProc.command = ["omarchy-menu-visibility", "set-option", name, value ? "true" : "false"]
    settingsProc.running = true
  }

  function confirmHide(id, stage) {
    confirmId = id
    confirmStage = stage
  }

  function confirmMessage() {
    if (confirmStage === 1) return "This hides Menu entries. You will not be able to open this window from the menu. Recovery: run omarchy launch menu-settings, or edit ~/.config/omarchy/menu-visibility.json."
    if (confirmStage === 2) return "You can still get back in from a terminal. Are you sure you want to hide the way back?"
    return "Last toggle. This one is the real one."
  }

  function nextConfirmation() {
    if (confirmStage < 3) confirmStage += 1
    else {
      setHidden(confirmId, true)
      confirmStage = 0
      confirmId = ""
    }
  }

  function acknowledge(id, visible) {
    reviewProc.command = ["omarchy-menu-visibility", "acknowledge", id, visible ? "visible" : "hidden"]
    reviewProc.running = true
  }

  function formatEvent(event) {
    var value = event.kind + "  " + event.id + "  ·  " + event.date + "  ·  " + event.version
    if (event.kind === "added" && event.new) value += "\n" + (event.new.label || event.id)
    if (event.kind === "removed" && event.old) value += "\n" + (event.old.label || event.id)
    if (event.kind === "renamed" && event.from) value += "\nRenamed from: " + event.from
    if ((event.kind === "modified" || event.kind === "renamed") && event.old && event.new) {
      var fields = Object.keys(event.new)
      for (var i = 0; i < fields.length; i++) {
        var field = fields[i]
        if (JSON.stringify(event.old[field]) === JSON.stringify(event.new[field])) continue
        value += "\n" + field + ": " + JSON.stringify(event.old[field] === undefined ? "(none)" : event.old[field]) + " → " + JSON.stringify(event.new[field])
      }
    }
    return value
  }

  function historyRows() {
    var rows = []
    var previous = ""
    var events = root.historyData.events || []
    for (var i = events.length - 1; i >= 0; i--) {
      var event = events[i]
      var group = event.date + "  ·  " + event.version
      if (group !== previous) rows.push({heading:group})
      rows.push({event:event})
      previous = group
    }
    return rows
  }

  function reviewText(review) {
    var notes = Array.isArray(review.notes) ? review.notes : []
    var value = review.note || ""
    for (var i = 0; i < notes.length; i++) if (notes[i].note) value += (value ? "\n" : "") + notes[i].note + (notes[i].url ? "\n" + notes[i].url : "")
    if (review.url) value += (value ? "\n" : "") + review.url
    return value || "Release-note mention"
  }

  FileView {
    id: defaultMenuFile
    path: root.omarchyPath + "/default/omarchy/omarchy-menu.jsonc"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var parsed = MenuModel.parseMenuJsonc(text())
      root.defaultEntries = parsed
      var merged = MenuModel.mergeMenuSources(parsed, root.userEntries)
      root.menuItems = merged.items
      root.itemOrder = merged.itemOrder
      root.refreshRows()
    }
    onFileChanged: reload()
  }

  FileView {
    id: extensionFile
    path: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var parsed = MenuModel.parseMenuJsonc(text())
      root.userEntries = parsed
      var merged = MenuModel.mergeMenuSources(root.defaultEntries, root.userEntries)
      root.menuItems = merged.items
      root.itemOrder = merged.itemOrder
      root.refreshRows()
    }
    onLoadFailed: {
      root.userEntries = []
      var merged = MenuModel.mergeMenuSources(root.defaultEntries, [])
      root.menuItems = merged.items
      root.itemOrder = merged.itemOrder
      root.refreshRows()
    }
    onFileChanged: reload()
  }

  FileView {
    id: settingsFile
    path: Quickshell.env("HOME") + "/.config/omarchy/menu-visibility.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { root.settings = JSON.parse(text()) } catch (e) { root.settings = {hidden:{}, globalUnhide:false, notifications:true, reviews:true} }
    }
    onLoadFailed: root.settings = {hidden:{}, globalUnhide:false, notifications:true, reviews:true}
    onFileChanged: reload()
  }

  Process {
    id: settingsProc
    onExited: settingsFile.reload()
  }
  Process {
    id: reconcileProc
    command: ["omarchy-menu-visibility", "reconcile"]
    running: false
    onExited: if (historyProc) historyProc.running = true
  }
  Process {
    id: historyProc
    command: ["omarchy-menu-visibility", "history"]
    stdout: StdioCollector { id: historyOutput }
    onExited: {
      try { root.historyData = JSON.parse(historyOutput.text) } catch (e) { root.historyData = {events:[],pending:[]} }
      historyRepeater.model = root.historyRows()
    }
  }
  Process {
    id: reviewProc
    onExited: {
      historyProc.running = true
      settingsFile.reload()
    }
  }

  FloatingWindow {
    id: window
    title: "Menu entries"
    color: Color.background
    visible: false
    implicitWidth: 680
    implicitHeight: 760
    minimumSize: Qt.size(480, 420)
    onVisibleChanged: if (!visible && !root.closingFromHost) root.hideSelf()

    FocusScope {
      anchors.fill: parent
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(22)
        spacing: Style.space(12)

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: root.view === "entries" ? "Menu entries" : "Menu changes"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            Layout.fillWidth: true
          }
          Button { text: "Entries"; onClicked: root.view = "entries" }
          Button { text: "Changes"; onClicked: { root.view = "changes"; historyProc.running = true } }
        }

        ColumnLayout {
          visible: root.view === "entries"
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(10)

          Toggle {
            Layout.fillWidth: true
            label: "Unhide all menu entries"
            description: "Explore the full menu, including options unavailable on this machine. Unavailable actions stay disabled."
            checked: !!root.settings.globalUnhide
            onClicked: root.setOption("globalUnhide", !root.settings.globalUnhide)
          }

          TextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: "Filter menu entries…"
            text: root.query
            onTextChanged: { root.query = text; root.refreshRows() }
          }

          Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded
            Column {
              width: parent.width
              spacing: Style.space(3)
              Repeater {
                model: root.rows
                delegate: Toggle {
                  required property var modelData
                  width: parent.width
                  label: (modelData.depth > 0 ? new Array(modelData.depth + 1).join("  ") : "") + modelData.label
                  description: modelData.kind === "menu" ? modelData.id : modelData.description
                  checked: !!root.settings.hidden[modelData.id]
                  enabled: !root.settings.globalUnhide && !root.hasHiddenAncestor(modelData.parent)
                  opacity: enabled ? 1 : 0.42
                  onClicked: {
                    if (checked) root.setHidden(modelData.id, false)
                    else if (modelData.id === "setup" || modelData.id === "setup.menu-entries") root.confirmHide(modelData.id, 1)
                    else root.setHidden(modelData.id, true)
                  }
                }
              }
            }
          }

          Toggle {
            Layout.fillWidth: true
            label: "Enable notifications"
            checked: root.settings.notifications !== false
            onClicked: root.setOption("notifications", !checked)
          }
          Toggle {
            Layout.fillWidth: true
            label: "Enable hidden-command reviews"
            description: "Ask after updates when a hidden command changes or appears in release notes."
            checked: root.settings.reviews !== false
            onClicked: root.setOption("reviews", !checked)
          }
        }

        ColumnLayout {
          visible: root.view === "changes"
          Layout.fillWidth: true
          Layout.fillHeight: true
          Text {
            Layout.fillWidth: true
            text: root.historyData.pending.length + " hidden command review(s) pending"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
          }
          Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Column {
              width: parent.width
              spacing: Style.space(10)
              Repeater {
                model: root.historyData.pending
                delegate: BorderSurface {
                  required property var modelData
                  width: parent.width
                  implicitHeight: pendingColumn.implicitHeight + Style.space(20)
                  color: Style.normalFillFor(Color.foreground, Color.accent)
                  ColumnLayout {
                    id: pendingColumn
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    Text { text: modelData.id + "  ·  " + modelData.date + "  ·  " + modelData.version; color: Color.foreground; font.bold: true; Layout.fillWidth: true }
                    Text { text: "Old: " + (modelData.oldAction || "(none)") + "\nNew: " + (modelData.newAction || root.reviewText(modelData)); color: Color.foreground; wrapMode: Text.Wrap; Layout.fillWidth: true; textFormat: Text.PlainText }
                    RowLayout {
                      Layout.alignment: Qt.AlignRight
                      Button { text: "Keep hidden"; onClicked: root.acknowledge(modelData.id, false) }
                      Button { text: "Show entry"; onClicked: root.acknowledge(modelData.id, true) }
                    }
                  }
                }
              }
              Repeater {
                id: historyRepeater
                model: root.historyRows()
                delegate: Text {
                  required property var modelData
                  Layout.fillWidth: true
                  text: modelData.heading !== undefined ? modelData.heading : root.formatEvent(modelData.event)
                  color: Color.foreground
                  wrapMode: Text.Wrap
                  textFormat: Text.PlainText
                  font.family: Style.font.family
                  font.pixelSize: modelData.heading !== undefined ? Style.font.subtitle : Style.font.body
                  font.bold: modelData.heading !== undefined
                }
              }
            }
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: root.confirmStage > 0
        color: "#b8000000"
        z: 5
        MouseArea { anchors.fill: parent; onClicked: {} }
        BorderSurface {
          id: confirmationCard
          width: Math.min(parent.width - Style.space(40), Style.space(480))
          implicitHeight: confirmationColumn.implicitHeight + Style.space(40)
          anchors.centerIn: parent
          color: Color.background
          radius: Style.cornerRadius
          padding: Style.space(20)
          ColumnLayout {
            id: confirmationColumn
            anchors.fill: parent
            spacing: Style.space(14)
            Text { text: "Hide the way back?"; color: Color.foreground; font.bold: true; font.pixelSize: Style.font.title }
            Text { text: root.confirmMessage(); color: Color.foreground; wrapMode: Text.Wrap; Layout.fillWidth: true }
            RowLayout {
              Layout.alignment: Qt.AlignRight
              Button { text: "Cancel"; onClicked: { root.confirmStage = 0; root.confirmId = "" } }
              Toggle {
                label: root.confirmStage === 1 ? "Hide it anyway" : (root.confirmStage === 2 ? "Yes, really" : "I know the way back")
                checked: false
                onClicked: root.nextConfirmation()
              }
            }
          }
        }
      }
    }
  }

  Component.onCompleted: reconcileProc.running = true
}
