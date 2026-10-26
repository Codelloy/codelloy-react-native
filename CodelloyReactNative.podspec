require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

# The XCFramework must be the native SDK version that codelloyNative pins. Without this check, a missing or old binary
# fails only later, in the app build.
native = package["codelloyNative"]["version"]
plist = File.join(__dir__, "ios/Frameworks/CodelloySDK.xcframework/ios-arm64/CodelloySDK.framework/Info.plist")
# No shell: the path of the app can hold $, ` or ".
plutil = ["plutil", "-extract", "CFBundleShortVersionString", "raw", "-o", "-", plist]
found = File.exist?(plist) ? IO.popen(plutil, &:read).strip : "missing"
if found != native
  raise "ios/Frameworks/CodelloySDK.xcframework is #{found}, but codelloyNative in package.json pins #{native}. " \
        "Run scripts/fetch-native.sh, or scripts/native-dev.sh for a development build"
end

Pod::Spec.new do |s|
  s.name         = "CodelloyReactNative"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  # The deployment target of the native SDK.
  s.platforms    = { :ios => "15.0" }
  s.source       = { :git => "https://github.com/Codelloy/codelloy-react-native.git", :tag => "v#{s.version}" }

  # Only the glue. The XCFramework has its own headers.
  s.source_files = "ios/*.{mm,swift}"
  # An app with an Objective-C app target has no SWIFT_VERSION.
  s.swift_version = "5.0"
  # scripts/fetch-native.sh (before npm pack) or scripts/native-dev.sh puts the native SDK here. Git does not hold it.
  s.vendored_frameworks = "ios/Frameworks/CodelloySDK.xcframework"

  install_modules_dependencies(s)
end
