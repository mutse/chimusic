package app.chimusic.player

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.util.Base64
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : AudioServiceActivity() {
  companion object {
    private const val channelName = "chimusic.apple_media_access"
    private const val openAudioFilesRequestCode = 4101
    private const val bookmarkRegistryName = "chimusic.android_media_access"
    private const val bookmarkPathPrefix = "bookmark_path_v1:"
    private const val importsDirectoryName = "chimusic_imports"
  }

  private var pendingPickAudioFilesResult: MethodChannel.Result? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      channelName,
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "pickAudioFiles" -> pickAudioFiles(result)
        "createBookmarks" -> createBookmarks(call, result)
        "startAccessingBookmark" -> startAccessingBookmark(call, result)
        "stopAccessingBookmark" -> result.success(null)
        else -> result.notImplemented()
      }
    }
  }

  override fun onActivityResult(
    requestCode: Int,
    resultCode: Int,
    data: Intent?,
  ) {
    if (requestCode == openAudioFilesRequestCode) {
      handlePickedAudioFiles(resultCode, data)
      return
    }

    super.onActivityResult(requestCode, resultCode, data)
  }

  private fun pickAudioFiles(result: MethodChannel.Result) {
    if (pendingPickAudioFilesResult != null) {
      result.error(
        "picker_in_progress",
        "An audio picker request is already active.",
        null,
      )
      return
    }

    pendingPickAudioFilesResult = result
    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
      addCategory(Intent.CATEGORY_OPENABLE)
      type = "audio/*"
      putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
    }
    startActivityForResult(intent, openAudioFilesRequestCode)
  }

  private fun handlePickedAudioFiles(resultCode: Int, data: Intent?) {
    val result = pendingPickAudioFilesResult ?: return
    pendingPickAudioFilesResult = null

    if (resultCode != Activity.RESULT_OK || data == null) {
      result.success(emptyList<Map<String, Any?>>())
      return
    }

    val grantFlags =
      data.flags and
        (Intent.FLAG_GRANT_READ_URI_PERMISSION or
          Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
    val selectedUris = linkedSetOf<Uri>().apply {
      data.data?.let(::add)
      val clipData = data.clipData
      if (clipData != null) {
        for (index in 0 until clipData.itemCount) {
          clipData.getItemAt(index).uri?.let(::add)
        }
      }
    }.toList()

    Thread {
      val payload = selectedUris.mapNotNull { uri ->
        buildPickedAudioPayload(uri, grantFlags)
      }
      runOnUiThread {
        result.success(payload)
      }
    }.start()
  }

  private fun createBookmarks(
    call: MethodCall,
    result: MethodChannel.Result,
  ) {
    val arguments = call.arguments as? Map<*, *>
    val locators = arguments?.get("paths") as? List<*>
    if (locators == null) {
      result.success(emptyList<Map<String, Any?>>())
      return
    }

    val payload = locators
      .mapNotNull { locator -> locator as? String }
      .mapNotNull { locator ->
        buildBookmarkForLocator(locator)?.let { bookmark ->
          mapOf(
            "path" to locator,
            "bookmarkBase64" to bookmark,
          )
        }
      }
    result.success(payload)
  }

  private fun startAccessingBookmark(
    call: MethodCall,
    result: MethodChannel.Result,
  ) {
    val arguments = call.arguments as? Map<*, *>
    val bookmarkBase64 = arguments?.get("bookmarkBase64") as? String
    if (bookmarkBase64.isNullOrBlank()) {
      result.error(
        "invalid_bookmark",
        "Bookmark payload is missing or malformed.",
        null,
      )
      return
    }

    val locator = decodeBookmark(bookmarkBase64)
    if (locator.isNullOrBlank()) {
      result.error(
        "invalid_bookmark",
        "Bookmark payload could not be decoded.",
        null,
      )
      return
    }

    try {
      val uri = Uri.parse(locator)
      when (uri.scheme) {
        "content" -> {
          val localFile = copyUriToStableImportPath(uri)
          rememberLocalPath(uri.toString(), localFile.path)
          result.success(
            mapOf(
              "path" to localFile.path,
            ),
          )
        }
        "file" -> {
          val file = File(uri.path ?: "")
          if (!file.exists()) {
            result.success(null)
            return
          }
          result.success(mapOf("path" to file.path))
        }
        else -> {
          val file = File(locator)
          if (!file.exists()) {
            result.success(null)
            return
          }
          result.success(mapOf("path" to file.path))
        }
      }
    } catch (error: Exception) {
      result.error(
        "bookmark_resolution_failed",
        error.localizedMessage,
        null,
      )
    }
  }

  private fun buildPickedAudioPayload(
    uri: Uri,
    grantFlags: Int,
  ): Map<String, Any?>? {
    return try {
      takePersistableReadPermission(uri, grantFlags)
      val localFile = copyUriToStableImportPath(uri)
      rememberLocalPath(uri.toString(), localFile.path)
      mapOf(
        "path" to localFile.path,
        "locator" to uri.toString(),
        "bookmarkBase64" to requireNotNull(buildBookmarkForLocator(uri.toString())),
        "platform" to "android",
      )
    } catch (_: Exception) {
      null
    }
  }

  private fun takePersistableReadPermission(uri: Uri, grantFlags: Int) {
    try {
      contentResolver.takePersistableUriPermission(
        uri,
        grantFlags and
          (Intent.FLAG_GRANT_READ_URI_PERMISSION or
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION),
      )
    } catch (_: SecurityException) {
      // Best effort. Some providers grant direct access without persistable flags.
    } catch (_: IllegalArgumentException) {
      // Ignore providers that reject persisted grants.
    }
  }

  private fun buildBookmarkForLocator(locator: String): String? {
    val normalized = locator.trim()
    if (normalized.isEmpty()) {
      return null
    }

    if (normalized.startsWith("content://") || normalized.startsWith("file://")) {
      return encodeBookmark(normalized)
    }

    val rememberedUri = rememberedUriForPath(normalized)
    if (!rememberedUri.isNullOrBlank()) {
      return encodeBookmark(rememberedUri)
    }

    return encodeBookmark(Uri.fromFile(File(normalized)).toString())
  }

  private fun copyUriToStableImportPath(uri: Uri): File {
    val fileName = resolveFileName(uri)
    val parentLabel = deriveParentLabel(uri)
    val parentDirectory = File(cacheDir, "$importsDirectoryName/$parentLabel")
    if (!parentDirectory.exists()) {
      parentDirectory.mkdirs()
    }

    val targetFile = targetFileForUri(parentDirectory, fileName, uri.toString())
    contentResolver.openInputStream(uri).use { input ->
      val source = requireNotNull(input) {
        "Unable to open the selected audio file."
      }
      FileOutputStream(targetFile).use { output ->
        source.copyTo(output)
        output.flush()
      }
    }
    return targetFile
  }

  private fun targetFileForUri(
    parentDirectory: File,
    fileName: String,
    locator: String,
  ): File {
    val defaultFile = File(parentDirectory, fileName)
    if (!defaultFile.exists()) {
      return defaultFile
    }

    val rememberedUri = rememberedUriForPath(defaultFile.path)
    if (rememberedUri == null || rememberedUri == locator) {
      return defaultFile
    }

    return File(
      parentDirectory,
      appendHashSuffix(fileName, shortHash(locator)),
    )
  }

  private fun resolveFileName(uri: Uri): String {
    val displayName = queryDisplayName(uri)
    if (!displayName.isNullOrBlank()) {
      return sanitizeFileName(displayName)
    }

    val fallback =
      uri.lastPathSegment
        ?.substringAfterLast('/')
        ?.substringAfterLast(':')
        ?.takeIf { it.isNotBlank() }
        ?: "imported-audio"
    return sanitizeFileName(fallback)
  }

  private fun deriveParentLabel(uri: Uri): String {
    return try {
      val documentId = DocumentsContract.getDocumentId(uri)
      val relativePath = documentId.substringAfter(':', "")
      val parent = relativePath.substringBeforeLast('/', "")
      val label = parent.substringAfterLast('/').trim()
      sanitizeDirectoryName(label.ifEmpty { "imported-audio" })
    } catch (_: IllegalArgumentException) {
      "imported-audio"
    }
  }

  private fun queryDisplayName(uri: Uri): String? {
    val cursor =
      contentResolver.query(
        uri,
        arrayOf(OpenableColumns.DISPLAY_NAME),
        null,
        null,
        null,
      ) ?: return null

    cursor.use {
      if (!it.moveToFirst()) {
        return null
      }
      val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
      if (index < 0) {
        return null
      }
      return it.getString(index)
    }
  }

  private fun rememberLocalPath(
    locator: String,
    localPath: String,
  ) {
    getSharedPreferences(bookmarkRegistryName, MODE_PRIVATE)
      .edit()
      .putString(pathKey(localPath), locator)
      .apply()
  }

  private fun rememberedUriForPath(path: String): String? {
    return getSharedPreferences(bookmarkRegistryName, MODE_PRIVATE)
      .getString(pathKey(path), null)
  }

  private fun pathKey(path: String): String {
    return bookmarkPathPrefix + shortHash(path)
  }

  private fun encodeBookmark(locator: String): String {
    return Base64.encodeToString(
      locator.toByteArray(Charsets.UTF_8),
      Base64.NO_WRAP,
    )
  }

  private fun decodeBookmark(bookmarkBase64: String): String? {
    return try {
      val decoded = Base64.decode(bookmarkBase64, Base64.DEFAULT)
      String(decoded, Charsets.UTF_8)
    } catch (_: IllegalArgumentException) {
      if (bookmarkBase64.startsWith("content://") || bookmarkBase64.startsWith("file://")) {
        bookmarkBase64
      } else {
        null
      }
    }
  }

  private fun sanitizeFileName(value: String): String {
    return value
      .replace('/', '_')
      .replace('\\', '_')
      .replace("..", "_")
      .trim()
      .ifEmpty { "imported-audio" }
  }

  private fun sanitizeDirectoryName(value: String): String {
    return sanitizeFileName(value)
      .replace(' ', '-')
      .lowercase()
  }

  private fun appendHashSuffix(
    fileName: String,
    suffix: String,
  ): String {
    val extensionIndex = fileName.lastIndexOf('.')
    if (extensionIndex <= 0 || extensionIndex == fileName.lastIndex) {
      return "${fileName}_$suffix"
    }

    val stem = fileName.substring(0, extensionIndex)
    val extension = fileName.substring(extensionIndex)
    return "${stem}_$suffix$extension"
  }

  private fun shortHash(value: String): String {
    return value
      .toByteArray(Charsets.UTF_8)
      .fold(0) { current, unit -> (current * 31 + unit) and 0x7fffffff }
      .toString(16)
  }
}
