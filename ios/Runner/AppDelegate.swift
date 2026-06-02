import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appleMediaAccessPlugin = AppleMediaAccessPlugin()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    appleMediaAccessPlugin.register(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}

final class AppleMediaAccessPlugin: NSObject, UIDocumentPickerDelegate {
  private var pendingResult: FlutterResult?
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
    case "pickAudioFiles":
      presentPicker(result: result)
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

  private func presentPicker(result: @escaping FlutterResult) {
    guard pendingResult == nil else {
      result(
        FlutterError(
          code: "picker_in_progress",
          message: "An audio picker request is already active.",
          details: nil
        )
      )
      return
    }

    guard let viewController = topViewController() else {
      result(
        FlutterError(
          code: "missing_view_controller",
          message: "Unable to find a view controller to present the document picker.",
          details: nil
        )
      )
      return
    }

    pendingResult = result
    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: false)
    } else {
      picker = UIDocumentPickerViewController(documentTypes: ["public.audio"], in: .open)
    }
    picker.allowsMultipleSelection = true
    picker.delegate = self
    picker.modalPresentationStyle = .formSheet
    viewController.present(picker, animated: true)
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
        options: bookmarkResolutionOptions(),
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
          options: bookmarkCreationOptions(),
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

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    let result = pendingResult
    pendingResult = nil
    controller.dismiss(animated: true)

    let payload = urls.compactMap(bookmarkPayload(for:))
    result?(payload)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = pendingResult
    pendingResult = nil
    controller.dismiss(animated: true)
    result?([])
  }

  private func topViewController() -> UIViewController? {
    let connectedScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = connectedScenes
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
    var current = window?.rootViewController
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
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

  private func bookmarkPayload(for url: URL) -> [String: Any]? {
    let didStartAccessing = url.startAccessingSecurityScopedResource()
    defer {
      if didStartAccessing {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let bookmark = try url.bookmarkData(
        options: bookmarkCreationOptions(),
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

  private func bookmarkCreationOptions() -> URL.BookmarkCreationOptions {
    #if os(macOS)
      return [.withSecurityScope]
    #else
      return [.minimalBookmark]
    #endif
  }

  private func bookmarkResolutionOptions() -> URL.BookmarkResolutionOptions {
    #if os(macOS)
      return [.withSecurityScope]
    #else
      return []
    #endif
  }
}
