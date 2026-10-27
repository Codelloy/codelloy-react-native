package com.codelloy.reactnative

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.turbomodule.core.interfaces.TurboModule

class CodelloyPackage : BaseReactPackage() {
    override fun getModule(
        name: String,
        reactContext: ReactApplicationContext,
    ): NativeModule? = if (name == CodelloyImpl.NAME) CodelloyModule(reactContext) else null

    override fun getReactModuleInfoProvider() =
        ReactModuleInfoProvider {
            // The module of src/newarch is a TurboModule, the module of src/oldarch is not.
            val isTurboModule = TurboModule::class.java.isAssignableFrom(CodelloyModule::class.java)
            mapOf(
                CodelloyImpl.NAME to
                    ReactModuleInfo(
                        CodelloyImpl.NAME,
                        CodelloyModule::class.java.name,
                        false,
                        false,
                        false,
                        isTurboModule,
                    ),
            )
        }
}
