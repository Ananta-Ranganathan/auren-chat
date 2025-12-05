package com.aurenchat

import android.graphics.Color
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.AurenChatViewManagerInterface
import com.facebook.react.viewmanagers.AurenChatViewManagerDelegate

@ReactModule(name = AurenChatViewManager.NAME)
class AurenChatViewManager : SimpleViewManager<AurenChatView>(),
  AurenChatViewManagerInterface<AurenChatView> {
  private val mDelegate: ViewManagerDelegate<AurenChatView>

  init {
    mDelegate = AurenChatViewManagerDelegate(this)
  }

  override fun getDelegate(): ViewManagerDelegate<AurenChatView>? {
    return mDelegate
  }

  override fun getName(): String {
    return NAME
  }

  public override fun createViewInstance(context: ThemedReactContext): AurenChatView {
    return AurenChatView(context)
  }

  @ReactProp(name = "color")
  override fun setColor(view: AurenChatView?, color: String?) {
    view?.setBackgroundColor(Color.parseColor(color))
  }

  companion object {
    const val NAME = "AurenChatView"
  }
}
