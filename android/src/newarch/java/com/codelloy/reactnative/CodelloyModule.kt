package com.codelloy.reactnative

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableMap

/** The TurboModule of the new architecture. Each method sends the call to [CodelloyImpl]. */
class CodelloyModule(
    reactContext: ReactApplicationContext,
) : NativeCodelloySpec(reactContext) {
    private val impl = CodelloyImpl(reactContext)

    override fun configure(
        key: String,
        clipboard: Boolean,
        signalMatching: Boolean,
        autoMatch: Boolean,
        minConfidence: String,
        debug: Boolean,
        baseUrl: String?,
        wrapper: String,
    ) = impl.configure(key, clipboard, signalMatching, autoMatch, minConfidence, debug, baseUrl, wrapper)

    override fun match(promise: Promise) = impl.match(promise)

    override fun getPendingLink(): WritableMap? = impl.getPendingLink()

    override fun handleLink(url: String): Boolean = impl.handleLink(url)

    override fun installId(): String? = impl.installId()

    override fun resetForTesting(): Boolean = impl.resetForTesting()

    override fun addListener(eventName: String) = impl.addListener()

    override fun removeListeners(count: Double) = impl.removeListeners(count.toInt())

    override fun invalidate() {
        impl.invalidate()
        super.invalidate()
    }
}
