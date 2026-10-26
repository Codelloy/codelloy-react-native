package com.codelloy.reactnative

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableMap

/** The module of the old architecture, with the methods of the spec. Each method sends the call to [CodelloyImpl]. */
class CodelloyModule(
    reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext) {
    private val impl = CodelloyImpl(reactContext)

    override fun getName() = CodelloyImpl.NAME

    // Sync, so a sync call right after init sees the configured SDK.
    @ReactMethod(isBlockingSynchronousMethod = true)
    fun configure(
        key: String,
        clipboard: Boolean,
        signalMatching: Boolean,
        autoMatch: Boolean,
        minConfidence: String,
        debug: Boolean,
        baseUrl: String?,
        wrapper: String,
    ): Boolean {
        impl.configure(key, clipboard, signalMatching, autoMatch, minConfidence, debug, baseUrl, wrapper)
        return true
    }

    @ReactMethod
    fun match(promise: Promise) = impl.match(promise)

    @ReactMethod(isBlockingSynchronousMethod = true)
    fun getPendingLink(): WritableMap? = impl.getPendingLink()

    @ReactMethod(isBlockingSynchronousMethod = true)
    fun handleLink(url: String): Boolean = impl.handleLink(url)

    @ReactMethod(isBlockingSynchronousMethod = true)
    fun installId(): String? = impl.installId()

    @ReactMethod(isBlockingSynchronousMethod = true)
    fun resetForTesting(): Boolean = impl.resetForTesting()

    @ReactMethod
    fun addListener(
        @Suppress("UNUSED_PARAMETER") eventName: String,
    ) = impl.addListener()

    @ReactMethod
    fun removeListeners(count: Double) = impl.removeListeners(count.toInt())

    override fun invalidate() {
        impl.invalidate()
        super.invalidate()
    }
}
