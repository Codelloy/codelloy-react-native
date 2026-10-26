package com.codelloy.reactnative

import android.net.Uri
import com.codelloy.Codelloy
import com.codelloy.CodelloyConfidence
import com.codelloy.CodelloyConfig
import com.codelloy.CodelloyLink
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableMap

/** The glue between the React Native module and the native SDK. The module of each architecture sends each call here. */
internal class CodelloyImpl(
    private val context: ReactApplicationContext,
) {
    private var listeners = 0

    /** The `init` of the JavaScript API. */
    fun configure(
        key: String,
        clipboard: Boolean,
        signalMatching: Boolean,
        autoMatch: Boolean,
        minConfidence: String,
        debug: Boolean,
        baseUrl: String?,
        wrapper: String,
    ) {
        val builder =
            CodelloyConfig
                .Builder(key)
                .clipboard(clipboard)
                .signalMatching(signalMatching)
                .autoMatch(autoMatch)
                .minConfidence(if (minConfidence == "medium") CodelloyConfidence.MEDIUM else CodelloyConfidence.HIGH)
                .debug(debug)
                .wrapper(wrapper)
        baseUrl?.let(builder::baseUrl)
        Codelloy.init(context, builder.build())
    }

    fun match(promise: Promise) {
        Codelloy.match { link, error ->
            if (error != null) {
                promise.reject(error.name, "The Codelloy match failed: ${error.name}")
            } else {
                promise.resolve(link?.let(::toMap))
            }
        }
    }

    fun getPendingLink(): WritableMap? = Codelloy.pendingLink?.let(::toMap)

    fun handleLink(url: String): Boolean = Codelloy.handleLink(Uri.parse(url))

    fun installId(): String? = Codelloy.installId

    fun resetForTesting(): Boolean = Codelloy.resetForTesting()

    /** The first JavaScript listener sets the handler. The SDK gives its pending link to the handler at once. */
    @Synchronized
    fun addListener() {
        if (listeners++ == 0) Codelloy.onLink { context.emitDeviceEvent(EVENT, toMap(it)) }
    }

    /** Without a JavaScript listener, the SDK keeps the next link as pending. */
    @Synchronized
    fun removeListeners(count: Int) {
        listeners = maxOf(0, listeners - count)
        if (listeners == 0) Codelloy.onLink(null)
    }

    @Synchronized
    fun invalidate() {
        listeners = 0
        Codelloy.onLink(null)
    }

    private fun toMap(link: CodelloyLink): WritableMap =
        Arguments.createMap().apply {
            putString("id", link.id)
            putString("url", link.url)
            putString("shortUrl", link.shortUrl)
            putBoolean("isDeferred", link.isDeferred)
            putString("matchType", link.matchType.name.lowercase())
            putString("confidence", link.confidence.name.lowercase())
        }

    companion object {
        /** The name of the module. Not `Codelloy`, the class name of the iOS SDK. */
        const val NAME = "RNCodelloy"
        private const val EVENT = "CodelloyLink"
    }
}
