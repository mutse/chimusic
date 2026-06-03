import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let appleMediaAccessPlugin = AppleMediaAccessPlugin()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    appleMediaAccessPlugin.register(
      messenger: flutterViewController.engine.binaryMessenger
    )

    super.awakeFromNib()
  }
}

final class AppleMediaAccessPlugin: NSObject {
  private var activeUrls: [String: URL] = [:]

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "chimusic.apple_media_access",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "createBookmarks":
      createBookmarks(call.arguments, result: result)
    case "startAccessingBookmark":
      startAccessingBookmark(call.arguments, result: result)
    case "stopAccessingBookmark":
      stopAccessingBookmark(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createBookmarks(_ arguments: Any?, result: @escaping FlutterResult) {
    guard
      let arguments = arguments as? [String: Any],
      let paths = arguments["paths"] as? [String]
    else {
      result([])
      return
    }

    let payload = paths.compactMap { path in
      bookmarkPayload(for: URL(fileURLWithPath: path))
    }
    result(payload)
  }

  private func startAccessingBookmark(_ arguments: Any?, result: @escaping FlutterResult) {
    guard
      let arguments = arguments as? [String: Any],
      let bookmarkBase64 = arguments["bookmarkBase64"] as? String,
      let bookmarkData = Data(base64Encoded: bookmarkBase64)
    else {
      result(
        FlutterError(
          code: "invalid_bookmark",
          message: "Bookmark payload is missing or malformed.",
          details: nil
        )
      )
      return
    }

    do {
      var isStale = false
      let url = try URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
      guard url.startAccessingSecurityScopedResource() else {
        result(nil)
        return
      }

      activeUrls[bookmarkBase64] = url
      var payload: [String: Any] = ["path": url.path]
      if isStale {
        let refreshedBookmark = try url.bookmarkData(
          options: [.withSecurityScope],
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )
        payload["bookmarkBase64"] = refreshedBookmark.base64EncodedString()
      }
      result(payload)
    } catch {
      result(
        FlutterError(
          code: "bookmark_resolution_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func stopAccessingBookmark(_ arguments: Any?, result: @escaping FlutterResult) {
    guard
      let arguments = arguments as? [String: Any],
      let bookmarkBase64 = arguments["bookmarkBase64"] as? String
    else {
      result(nil)
      return
    }

    if let url = activeUrls.removeValue(forKey: bookmarkBase64) {
      url.stopAccessingSecurityScopedResource()
    }
    result(nil)
  }

  private func bookmarkPayload(for url: URL) -> [String: Any]? {
    let didStartAccessing = url.startAccessingSecurityScopedResource()
    defer {
      if didStartAccessing {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let bookmark = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      return [
        "path": url.path,
        "bookmarkBase64": bookmark.base64EncodedString(),
      ]
    } catch {
      return nil
    }
  }
}
