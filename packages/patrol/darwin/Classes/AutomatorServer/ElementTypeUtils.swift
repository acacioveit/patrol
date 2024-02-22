#if PATROL_ENABLED

  import Foundation
  import XCTest

  private let elementTypeMap = [
    XCUIElement.ElementType.any: IOSElementType.any,
    XCUIElement.ElementType.other: IOSElementType.other,
    XCUIElement.ElementType.application: IOSElementType.application,
    XCUIElement.ElementType.group: IOSElementType.group,
    XCUIElement.ElementType.window: IOSElementType.window,
    XCUIElement.ElementType.sheet: IOSElementType.sheet,
    XCUIElement.ElementType.drawer: IOSElementType.drawer,
    XCUIElement.ElementType.alert: IOSElementType.alert,
    XCUIElement.ElementType.dialog: IOSElementType.dialog,
    XCUIElement.ElementType.button: IOSElementType.button,
    XCUIElement.ElementType.radioButton: IOSElementType.radioButton,
    XCUIElement.ElementType.radioGroup: IOSElementType.radioGroup,
    XCUIElement.ElementType.checkBox: IOSElementType.checkBox,
    XCUIElement.ElementType.disclosureTriangle: IOSElementType.disclosureTriangle,
    XCUIElement.ElementType.popUpButton: IOSElementType.popUpButton,
    XCUIElement.ElementType.comboBox: IOSElementType.comboBox,
    XCUIElement.ElementType.menuButton: IOSElementType.menuButton,
    XCUIElement.ElementType.toolbarButton: IOSElementType.toolbarButton,
    XCUIElement.ElementType.popover: IOSElementType.popover,
    XCUIElement.ElementType.keyboard: IOSElementType.keyboard,
    XCUIElement.ElementType.key: IOSElementType.key,
    XCUIElement.ElementType.navigationBar: IOSElementType.navigationBar,
    XCUIElement.ElementType.tabBar: IOSElementType.tabBar,
    XCUIElement.ElementType.tabGroup: IOSElementType.tabGroup,
    XCUIElement.ElementType.toolbar: IOSElementType.toolbar,
    XCUIElement.ElementType.statusBar: IOSElementType.statusBar,
    XCUIElement.ElementType.table: IOSElementType.table,
    XCUIElement.ElementType.tableRow: IOSElementType.tableRow,
    XCUIElement.ElementType.tableColumn: IOSElementType.tableColumn,
    XCUIElement.ElementType.outline: IOSElementType.outline,
    XCUIElement.ElementType.outlineRow: IOSElementType.outlineRow,
    XCUIElement.ElementType.browser: IOSElementType.browser,
    XCUIElement.ElementType.collectionView: IOSElementType.collectionView,
    XCUIElement.ElementType.slider: IOSElementType.slider,
    XCUIElement.ElementType.pageIndicator: IOSElementType.pageIndicator,
    XCUIElement.ElementType.progressIndicator: IOSElementType.progressIndicator,
    XCUIElement.ElementType.activityIndicator: IOSElementType.activityIndicator,
    XCUIElement.ElementType.segmentedControl: IOSElementType.segmentedControl,
    XCUIElement.ElementType.picker: IOSElementType.picker,
    XCUIElement.ElementType.pickerWheel: IOSElementType.pickerWheel,
    XCUIElement.ElementType.switch: IOSElementType.switch_,
    XCUIElement.ElementType.toggle: IOSElementType.toggle,
    XCUIElement.ElementType.link: IOSElementType.link,
    XCUIElement.ElementType.image: IOSElementType.image,
    XCUIElement.ElementType.icon: IOSElementType.icon,
    XCUIElement.ElementType.searchField: IOSElementType.searchField,
    XCUIElement.ElementType.scrollView: IOSElementType.scrollView,
    XCUIElement.ElementType.scrollBar: IOSElementType.scrollBar,
    XCUIElement.ElementType.staticText: IOSElementType.staticText,
    XCUIElement.ElementType.textField: IOSElementType.textField,
    XCUIElement.ElementType.secureTextField: IOSElementType.secureTextField,
    XCUIElement.ElementType.datePicker: IOSElementType.datePicker,
    XCUIElement.ElementType.textView: IOSElementType.textView,
    XCUIElement.ElementType.menu: IOSElementType.menu,
    XCUIElement.ElementType.menuItem: IOSElementType.menuItem,
    XCUIElement.ElementType.menuBar: IOSElementType.menuBar,
    XCUIElement.ElementType.menuBarItem: IOSElementType.menuBarItem,
    XCUIElement.ElementType.map: IOSElementType.map,
    XCUIElement.ElementType.webView: IOSElementType.webView,
    XCUIElement.ElementType.incrementArrow: IOSElementType.incrementArrow,
    XCUIElement.ElementType.decrementArrow: IOSElementType.decrementArrow,
    XCUIElement.ElementType.timeline: IOSElementType.timeline,
    XCUIElement.ElementType.ratingIndicator: IOSElementType.ratingIndicator,
    XCUIElement.ElementType.valueIndicator: IOSElementType.valueIndicator,
    XCUIElement.ElementType.splitGroup: IOSElementType.splitGroup,
    XCUIElement.ElementType.splitter: IOSElementType.splitter,
    XCUIElement.ElementType.relevanceIndicator: IOSElementType.relevanceIndicator,
    XCUIElement.ElementType.colorWell: IOSElementType.colorWell,
    XCUIElement.ElementType.helpTag: IOSElementType.helpTag,
    XCUIElement.ElementType.matte: IOSElementType.matte,
    XCUIElement.ElementType.dockItem: IOSElementType.dockItem,
    XCUIElement.ElementType.ruler: IOSElementType.ruler,
    XCUIElement.ElementType.rulerMarker: IOSElementType.rulerMarker,
    XCUIElement.ElementType.grid: IOSElementType.grid,
    XCUIElement.ElementType.levelIndicator: IOSElementType.levelIndicator,
    XCUIElement.ElementType.cell: IOSElementType.cell,
    XCUIElement.ElementType.layoutArea: IOSElementType.layoutArea,
    XCUIElement.ElementType.layoutItem: IOSElementType.layoutItem,
    XCUIElement.ElementType.handle: IOSElementType.handle,
    XCUIElement.ElementType.stepper: IOSElementType.stepper,
    XCUIElement.ElementType.tab: IOSElementType.tab,
    XCUIElement.ElementType.touchBar: IOSElementType.touchBar,
    XCUIElement.ElementType.statusItem: IOSElementType.statusItem,
  ]

  func getIOSElementType(elementType: XCUIElement.ElementType) -> IOSElementType {
      return elementTypeMap[elementType]!
  }

  func getXCUIElementType(elementType: IOSElementType) -> XCUIElement.ElementType {
      return elementTypeMap.first(where: {$1 == elementType})!.key
  }
#endif
