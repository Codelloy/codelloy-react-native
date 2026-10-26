import CodelloySDK
import Foundation

/// The glue between the React Native module and the native SDK. `Codelloy.mm` sends each call here, on both
/// architectures.
@objc(CodelloyImpl)
public final class CodelloyImpl: NSObject {
    private let emit: @Sendable ([String: Any]) -> Void

    /// - Parameter emit: Sends a link to JavaScript as an event.
    @objc public init(emit: @escaping @Sendable ([String: Any]) -> Void) {
        self.emit = emit
    }

    // The init of the JavaScript API. Primitive parameters give the same signature on both architectures.
    // swiftlint:disable:next function_parameter_count
    @objc public func configure(
        key: String,
        clipboard: Bool,
        signalMatching: Bool,
        autoMatch: Bool,
        minConfidence: String,
        debug: Bool,
        baseUrl: String?,
        wrapper: String
    ) {
        let config = CodelloyConfig(key: key)
        config.clipboard = clipboard
        config.signalMatching = signalMatching
        config.autoMatch = autoMatch
        config.minConfidence = minConfidence == "medium" ? .medium : .high
        config.debug = debug
        if let baseUrl, let url = URL(string: baseUrl) {
            config.baseURL = url
        }
        config.wrapper = wrapper
        Codelloy.configure(config)
    }

    @objc public func match(
        resolve: @escaping @Sendable (Any?) -> Void,
        reject: @escaping @Sendable (String, String) -> Void
    ) {
        Codelloy.match { link, error in
            if let error {
                reject(Self.code(of: error), error.localizedDescription)
            } else {
                resolve(link.map(Self.dictionary))
            }
        }
    }

    @objc public func pendingLink() -> [String: Any]? {
        Codelloy.pendingLink.map(Self.dictionary)
    }

    @objc public func handleLink(_ url: String) -> Bool {
        guard let url = URL(string: url) else { return false }
        return Codelloy.handleLink(url)
    }

    @objc public var installId: String { Codelloy.installId }

    @objc public func resetForTesting() -> Bool {
        Codelloy.resetForTesting()
    }

    /// JavaScript has a listener. The SDK gives its pending link to the handler at once.
    @objc public func startObserving() {
        let emit = emit
        Codelloy.onLink { link in emit(Self.dictionary(link)) }
    }

    /// JavaScript has no listener. The SDK keeps the next link as pending.
    @objc public func stopObserving() {
        Codelloy.onLink(nil)
    }

    private static func dictionary(_ link: CodelloyLink) -> [String: Any] {
        [
            "id": link.id,
            "url": link.url,
            "shortUrl": link.shortUrl,
            "isDeferred": link.isDeferred,
            "matchType": link.matchType == .signal ? "signal" : "exact",
            "confidence": confidence(link.confidence)
        ]
    }

    private static func confidence(_ value: CodelloyConfidence) -> String {
        switch value {
        case .low: "low"
        case .medium: "medium"
        default: "high"
        }
    }

    private static func code(of error: Error) -> String {
        switch error as? CodelloyError {
        case .notConfigured: "NOT_CONFIGURED"
        case .network: "NETWORK"
        default: "SERVER"
        }
    }
}
