require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

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
  # scripts/native-dev.sh puts the native SDK here. Git does not hold it.
  s.vendored_frameworks = "ios/Frameworks/CodelloySDK.xcframework"

  install_modules_dependencies(s)
end
