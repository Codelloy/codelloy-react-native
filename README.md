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

The native SDK binaries are not in git. The field `codelloyNative` in `package.json` pins the native SDK release: its `version`, and `sha256`, the SHA-256 of its iOS zip. The podspec, `android/build.gradle` and `scripts/fetch-native.sh` read the version only from this field. Until the first release, `sha256` is the placeholder (64 zeros), and CI skips the native builds.

- iOS: `scripts/fetch-native.sh` downloads `CodelloySDK-<version>.xcframework.zip` from the GitHub release `<version>` of `Codelloy/codelloy-ios`, checks its SHA-256 and unzips it into `ios/Frameworks/`. It stops on each error: the placeholder, a missing release, a network error or a wrong SHA-256. `npm pack` and `npm publish` run it first (`prepack`), so the npm package holds the XCFramework. `pod install` stops when `ios/Frameworks/` does not hold the pinned version.
- Android: Gradle gets `com.codelloy:codelloy-android:<version>` from Maven Central.

Before the first release, or for a native SDK change that is not released, `scripts/native-dev.sh` makes the binaries from a local checkout of the native SDK source. The checkout must have the pinned version:

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
scripts/test-fetch-native.sh     # scripts/fetch-native.sh against fixture zips
scripts/compat-app.sh 0.74.7 old ios    # a temporary app on React Native 0.74, old architecture
scripts/compat-app.sh latest new android
```

### Example app

`example/` is an app on React Native 0.83 with the new architecture and static frameworks. It uses the binaries of `scripts/native-dev.sh`, or of `scripts/fetch-native.sh` and Maven Central after a release.

1. `npm install` in the root and in `example/`. The install in `example/` makes `example/codelloy.local.json`, which git ignores.
2. Put your test key in `example/codelloy.local.json`. For a local backend, also set `baseUrl`, for example `http://localhost:8080/link` on the iOS simulator or `http://10.0.2.2:8080/link` on the Android emulator.
3. iOS: `cd example && bundle install && cd ios && bundle exec pod install`, then `npm run ios` in `example/`.
4. Android: `npm run android` in `example/`. A local build has no Play referrer. With a `pk_test_` key, the SDK reads a fake referrer: add `-Pcodelloy.testReferrer=cdl=<click token>` to the Gradle command, or put `codelloy.testReferrer` in `~/.gradle/gradle.properties`.

The app shows the install id and each link that `onLink` delivers.

## Release

The operator makes each release after approval, in this order:

1. **Native SDK.** Release the native SDK version first: the GitHub release `<version>` of `Codelloy/codelloy-ios` with `CodelloySDK-<version>.xcframework.zip`, and `com.codelloy:codelloy-android:<version>` on Maven Central.
2. **Pin.** Set `codelloyNative.version` in `package.json` to that version, and `codelloyNative.sha256` to the SHA-256 of the zip. It is the `checksum` in `Package.swift` of `codelloy-ios`, and `shasum -a 256` of the zip gives the same value. Set the package version in `package.json` and in `src/version.ts` (a test compares them). With the pin, CI builds the example and the compatibility apps on the released binaries. Merge the change into `master`.
3. **Dry run.** In GitHub Actions, run the workflow "Release" on `master` with `publish` off. It runs each check, the example builds and the compatibility apps, packs the package and keeps the tarball as the artifact `npm-package`. It publishes nothing.
4. **Publish, after approval.** Run "Release" on `master` with `publish` on. The publish job waits for the approval of the environment `npm`. Then it publishes the tarball of its run to npm with provenance. With `publish` on, a run on another branch fails.
5. Optional: tag the release commit `v<version>`.

The workflows read secrets only from GitHub secrets:

| Secret                                                   | Use                                                                                                                                                                                                                                                                                                                                                                                 |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NPM_TOKEN`                                              | An npm access token that can publish to the scope `@codelloy`. The npm organisation `codelloy` must exist. Put the secret in the environment `npm` (Settings, Environments), not in the repository secrets. Add the operator as the required reviewer of that environment, and set its "Deployment branches and tags" to `master` only. Then only a run on `master` gets the token. |
| `SCAN_TEAM_ID` and the other `SCAN_` secrets of `ci.yml` | The real identifying values. The secret scan fails when the git history holds one of them, and names only the secret. It skips a secret that is not set.                                                                                                                                                                                                                            |

## License

MIT
