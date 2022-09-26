//Generated by the protocol buffer compiler. DO NOT EDIT!
// source: contracts.proto

package pl.leancode.automatorserver.contracts;

@kotlin.jvm.JvmName("-initializenativeWidget")
inline fun nativeWidget(block: pl.leancode.automatorserver.contracts.NativeWidgetKt.Dsl.() -> kotlin.Unit): pl.leancode.automatorserver.contracts.Contracts.NativeWidget =
  pl.leancode.automatorserver.contracts.NativeWidgetKt.Dsl._create(pl.leancode.automatorserver.contracts.Contracts.NativeWidget.newBuilder()).apply { block() }._build()
object NativeWidgetKt {
  @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
  @com.google.protobuf.kotlin.ProtoDslMarker
  class Dsl private constructor(
    private val _builder: pl.leancode.automatorserver.contracts.Contracts.NativeWidget.Builder
  ) {
    companion object {
      @kotlin.jvm.JvmSynthetic
      @kotlin.PublishedApi
      internal fun _create(builder: pl.leancode.automatorserver.contracts.Contracts.NativeWidget.Builder): Dsl = Dsl(builder)
    }

    @kotlin.jvm.JvmSynthetic
    @kotlin.PublishedApi
    internal fun _build(): pl.leancode.automatorserver.contracts.Contracts.NativeWidget = _builder.build()

    /**
     * <code>string className = 1;</code>
     */
    var className: kotlin.String
      @JvmName("getClassName")
      get() = _builder.getClassName()
      @JvmName("setClassName")
      set(value) {
        _builder.setClassName(value)
      }
    /**
     * <code>string className = 1;</code>
     */
    fun clearClassName() {
      _builder.clearClassName()
    }

    /**
     * <code>string text = 2;</code>
     */
    var text: kotlin.String
      @JvmName("getText")
      get() = _builder.getText()
      @JvmName("setText")
      set(value) {
        _builder.setText(value)
      }
    /**
     * <code>string text = 2;</code>
     */
    fun clearText() {
      _builder.clearText()
    }

    /**
     * <code>string contentDescription = 3;</code>
     */
    var contentDescription: kotlin.String
      @JvmName("getContentDescription")
      get() = _builder.getContentDescription()
      @JvmName("setContentDescription")
      set(value) {
        _builder.setContentDescription(value)
      }
    /**
     * <code>string contentDescription = 3;</code>
     */
    fun clearContentDescription() {
      _builder.clearContentDescription()
    }

    /**
     * <code>bool focused = 4;</code>
     */
    var focused: kotlin.Boolean
      @JvmName("getFocused")
      get() = _builder.getFocused()
      @JvmName("setFocused")
      set(value) {
        _builder.setFocused(value)
      }
    /**
     * <code>bool focused = 4;</code>
     */
    fun clearFocused() {
      _builder.clearFocused()
    }

    /**
     * <code>bool enabled = 5;</code>
     */
    var enabled: kotlin.Boolean
      @JvmName("getEnabled")
      get() = _builder.getEnabled()
      @JvmName("setEnabled")
      set(value) {
        _builder.setEnabled(value)
      }
    /**
     * <code>bool enabled = 5;</code>
     */
    fun clearEnabled() {
      _builder.clearEnabled()
    }

    /**
     * <code>int32 childCount = 6;</code>
     */
    var childCount: kotlin.Int
      @JvmName("getChildCount")
      get() = _builder.getChildCount()
      @JvmName("setChildCount")
      set(value) {
        _builder.setChildCount(value)
      }
    /**
     * <code>int32 childCount = 6;</code>
     */
    fun clearChildCount() {
      _builder.clearChildCount()
    }

    /**
     * <code>string resourceName = 7;</code>
     */
    var resourceName: kotlin.String
      @JvmName("getResourceName")
      get() = _builder.getResourceName()
      @JvmName("setResourceName")
      set(value) {
        _builder.setResourceName(value)
      }
    /**
     * <code>string resourceName = 7;</code>
     */
    fun clearResourceName() {
      _builder.clearResourceName()
    }

    /**
     * <code>string applicationPackage = 8;</code>
     */
    var applicationPackage: kotlin.String
      @JvmName("getApplicationPackage")
      get() = _builder.getApplicationPackage()
      @JvmName("setApplicationPackage")
      set(value) {
        _builder.setApplicationPackage(value)
      }
    /**
     * <code>string applicationPackage = 8;</code>
     */
    fun clearApplicationPackage() {
      _builder.clearApplicationPackage()
    }

    /**
     * An uninstantiable, behaviorless type to represent the field in
     * generics.
     */
    @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
    class ChildrenProxy private constructor() : com.google.protobuf.kotlin.DslProxy()
    /**
     * <code>repeated .patrol.NativeWidget children = 9;</code>
     */
     val children: com.google.protobuf.kotlin.DslList<pl.leancode.automatorserver.contracts.Contracts.NativeWidget, ChildrenProxy>
      @kotlin.jvm.JvmSynthetic
      get() = com.google.protobuf.kotlin.DslList(
        _builder.getChildrenList()
      )
    /**
     * <code>repeated .patrol.NativeWidget children = 9;</code>
     * @param value The children to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addChildren")
    fun com.google.protobuf.kotlin.DslList<pl.leancode.automatorserver.contracts.Contracts.NativeWidget, ChildrenProxy>.add(value: pl.leancode.automatorserver.contracts.Contracts.NativeWidget) {
      _builder.addChildren(value)
    }
    /**
     * <code>repeated .patrol.NativeWidget children = 9;</code>
     * @param value The children to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignChildren")
    @Suppress("NOTHING_TO_INLINE")
    inline operator fun com.google.protobuf.kotlin.DslList<pl.leancode.automatorserver.contracts.Contracts.NativeWidget, ChildrenProxy>.plusAssign(value: pl.leancode.automatorserver.contracts.Contracts.NativeWidget) {
      add(value)
    }
    /**
     * <code>repeated .patrol.NativeWidget children = 9;</code>
     * @param values The children to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addAllChildren")
    fun com.google.protobuf.kotlin.DslList<pl.leancode.automatorserver.contracts.Contracts.NativeWidget, ChildrenProxy>.addAll(values: kotlin.collections.Iterable<pl.leancode.automatorserver.contracts.Contracts.NativeWidget>) {
      _builder.addAllChildren(values)
    }
    /**
     * <code>repeated .patrol.NativeWidget children = 9;</code>
     * @param values The children to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignAllChildren")
    @Suppress("NOTHING_TO_INLINE")
    inline operator fun com.google.protobuf.kotlin.DslList<pl.leancode.automatorserver.contracts.Contracts.NativeWidget, ChildrenProxy>.plusAssign(values: kotlin.collections.Iterable<pl.leancode.automatorserver.contracts.Contracts.NativeWidget>) {
      addAll(values)
    }
    /**
     * <code>repeated .patrol.NativeWidget children = 9;</code>
     * @param index The index to set the value at.
     * @param value The children to set.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("setChildren")
    operator fun com.google.protobuf.kotlin.DslList<pl.leancode.automatorserver.contracts.Contracts.NativeWidget, ChildrenProxy>.set(index: kotlin.Int, value: pl.leancode.automatorserver.contracts.Contracts.NativeWidget) {
      _builder.setChildren(index, value)
    }
    /**
     * <code>repeated .patrol.NativeWidget children = 9;</code>
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("clearChildren")
    fun com.google.protobuf.kotlin.DslList<pl.leancode.automatorserver.contracts.Contracts.NativeWidget, ChildrenProxy>.clear() {
      _builder.clearChildren()
    }

  }
}
@kotlin.jvm.JvmSynthetic
inline fun pl.leancode.automatorserver.contracts.Contracts.NativeWidget.copy(block: pl.leancode.automatorserver.contracts.NativeWidgetKt.Dsl.() -> kotlin.Unit): pl.leancode.automatorserver.contracts.Contracts.NativeWidget =
  pl.leancode.automatorserver.contracts.NativeWidgetKt.Dsl._create(this.toBuilder()).apply { block() }._build()
