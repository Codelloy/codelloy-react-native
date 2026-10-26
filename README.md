# @codelloy/react-native

React Native SDK for Codelloy deep links and deferred deep linking. Documentation: https://codelloy.com/docs/sdks

- React Native 0.74 or later, on the new and the old architecture.
- iOS 15.0 or later.
- Android: the package builds with `minSdkVersion` 24. The SDK sends requests on Android 7.1 (API 25) or later, because older versions do not trust the certificate of the server.

## Install

```sh
npm install @codelloy/react-native
cd ios && pod install
```

The package links itself. The SDK adds no code to the AppDelegate or the MainActivity, and needs no Expo config plugin. It gets links through React Native `Linking` (see [Links that open the app](#links-that-open-the-app)).

## Setup

```ts
import * as Codelloy from '@codelloy/react-native';

// One time at launch, for example in index.js.
Codelloy.init({ key: '<your pk_live_ or pk_test_ key>' });

// Route the app here, and only here. link.url is the deep link, for example shop://product/42.
const remove = Codelloy.onLink((link) => {
  console.log(link.url, link.isDeferred, link.matchType, link.confidence);
});
```

`onLink` gets the deferred link of the first launch after the install, and each link that opens the app. A link that arrives before the first listener goes to that listener, also before `onLink` returns. Each link goes to the listeners one time. The function that `onLink` returns removes the listener. Keep one listener for the life of the app: a link that arrives while the last listener is being removed can be lost.

The SDK reads each URL of React Native `Linking` by itself. `handleLink(url)` returns `true` for a URL on a link domain of your organisation. For each other URL it returns `false`, and the app handles the URL itself. Do not give `handleLink` a URL of React Native `Linking`: the SDK already has it, and each call resolves the link again.

| `init` option    | Default         | Effect                                                                                                  |
| ---------------- | --------------- | ------------------------------------------------------------------------------------------------------- |
| `key`            |                 | Your SDK key.                                                                                           |
| `clipboard`      | `true`          | iOS: reads the click token from the clipboard at the first launch. iOS can show a paste alert.          |
| `signalMatching` | `true`          | Sends the screen size for a signal match. With `false`, only exact matches.                             |
| `autoMatch`      | `true`          | With `false`, the SDK reads and sends nothing until the app calls `match()`, for example after consent. |
| `minConfidence`  | `'high'`        | `'medium'` also delivers medium signal matches.                                                         |
| `debug`          | `false`         | Writes SDK lines to the Xcode console and to Logcat.                                                    |
| `baseUrl`        | Codelloy server | Set it only for a local backend.                                                                        |

`installId()` gives the id of this install, or `null` on Android before `init`. `resetForTesting()` deletes the install state, so the next `match()` runs as on a fresh install. It works only with a `pk_test_` key.

## Links that open the app

The SDK does not change your native projects. For links on your custom link domain, for example `links.example.com`, the app needs:

**iOS, Universal Links.** The Associated Domains capability with this entitlement:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:links.example.com</string>
</array>
```

React Native `Linking` gets a link that arrives while the app runs only through `RCTLinkingManager` in the AppDelegate. This is the standard setup of React Native `Linking`. See https://reactnative.dev/docs/linking. In a Swift AppDelegate:

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
  RCTLinkingManager.application(app, open: url, options: options)
}

func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
  RCTLinkingManager.application(application, continue: userActivity, restorationHandler: restorationHandler)
}
```

**Android, App Links.** An intent filter with `autoVerify` on the activity of React Native, in `AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="links.example.com" />
</intent-filter>
```

Add the bundle ID with the Team ID, and the package name with the SHA-256 fingerprints of the signing keys, to your app on the Manage Apps page. Codelloy then serves the `apple-app-site-association` and `assetlinks.json` files of your domain.

## Development

The native SDK binaries are not in git. Until the first release, `scripts/native-dev.sh` makes them from a local checkout of the native SDK source:

```sh
CODELLOY_NATIVE_DIR=/path/to/native-sdk-source scripts/native-dev.sh        # ios and android
```

- iOS: the XCFramework goes to `ios/Frameworks/CodelloySDK.xcframework`.
- Android: `com.codelloy:codelloy-android` goes to Maven Local. The Gradle build of the app must read Maven Local for the group `com.codelloy`, as `example/android/build.gradle` does. Gradle needs JDK 17 or 21.

Checks:

```sh
npm install
npm run lint && npm run typecheck && npm test
scripts/lint-native.sh           # SwiftLint, clang-format and ktlint (macOS, Java on the PATH)
scripts/secret-scan.sh           # gitleaks
scripts/compat-app.sh 0.74.7 old ios    # a temporary app on React Native 0.74, old architecture
scripts/compat-app.sh latest new android
```

### Example app

`example/` is an app on React Native 0.83 with the new architecture and static frameworks. It uses the binaries of `scripts/native-dev.sh`.

1. `npm install` in the root and in `example/`. The install in `example/` makes `example/codelloy.local.json`, which git ignores.
2. Put your test key in `example/codelloy.local.json`. For a local backend, also set `baseUrl`, for example `http://localhost:8080/link` on the iOS simulator or `http://10.0.2.2:8080/link` on the Android emulator.
3. iOS: `cd example && bundle install && cd ios && bundle exec pod install`, then `npm run ios` in `example/`.
4. Android: `npm run android` in `example/`. A local build has no Play referrer. With a `pk_test_` key, the SDK reads a fake referrer: add `-Pcodelloy.testReferrer=cdl=<click token>` to the Gradle command, or put `codelloy.testReferrer` in `~/.gradle/gradle.properties`.

The app shows the install id and each link that `onLink` delivers.

## License

MIT
