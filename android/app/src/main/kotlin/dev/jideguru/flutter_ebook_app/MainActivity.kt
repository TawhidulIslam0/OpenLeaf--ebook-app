package dev.jideguru.flutter_ebook_app

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val coverExecutor = Executors.newFixedThreadPool(4)
    private var downloadProgressSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.jideguru.flutter_ebook_app/book_covers",
        ).setMethodCallHandler { call, result ->
            if (call.method != "loadCover") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val imageUrl = call.argument<String>("url")
            val uri = imageUrl?.let(Uri::parse)
            val host = uri?.host
            val isGutenbergHost = host == "gutenberg.org" ||
                host?.endsWith(".gutenberg.org") == true
            if (uri == null ||
                uri.scheme != "https" ||
                !isGutenbergHost && host != "images.weserv.nl"
            ) {
                result.error("invalid_url", "Unsupported cover image URL.", null)
                return@setMethodCallHandler
            }

            coverExecutor.execute {
                var connection: HttpURLConnection? = null
                try {
                    val imageConnection =
                        URL(imageUrl).openConnection() as HttpURLConnection
                    connection = imageConnection
                    imageConnection.connectTimeout = 15000
                    imageConnection.readTimeout = 15000
                    imageConnection.setRequestProperty("User-Agent", "OpenLeaf eBook Reader")
                    imageConnection.connect()
                    val statusCode = imageConnection.responseCode
                    if (statusCode !in 200..299) {
                        throw IllegalStateException("Cover request returned HTTP $statusCode.")
                    }
                    if (imageConnection.contentType?.startsWith("image/") != true) {
                        throw IllegalStateException("Cover response was not an image.")
                    }

                    val bytes = imageConnection.inputStream.use { input ->
                        val output = java.io.ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        var totalBytes = 0
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            totalBytes += count
                            if (totalBytes > 8 * 1024 * 1024) {
                                throw IllegalStateException("Cover image exceeds 8 MB.")
                            }
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    }
                    runOnUiThread { result.success(bytes) }
                } catch (error: Exception) {
                    runOnUiThread {
                        result.error("cover_load_failed", error.message, null)
                    }
                } finally {
                    connection?.disconnect()
                }
            }
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.jideguru.flutter_ebook_app/book_download_progress",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                downloadProgressSink = events
            }

            override fun onCancel(arguments: Any?) {
                downloadProgressSink = null
            }
        })
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.jideguru.flutter_ebook_app/book_downloads",
        ).setMethodCallHandler { call, result ->
            if (call.method != "downloadBook") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val downloadUrl = call.argument<String>("url")
            val filePath = call.argument<String>("filePath")
            if (downloadUrl == null || filePath == null ||
                !isGutenbergUrl(downloadUrl) ||
                !isAppPrivatePath(filePath)
            ) {
                result.error("invalid_download", "Invalid book URL or save path.", null)
                return@setMethodCallHandler
            }

            coverExecutor.execute {
                val destination = File(filePath)
                val temporaryFile = File("$filePath.part")
                try {
                    destination.parentFile?.mkdirs()
                    val totalBytes = downloadToFile(downloadUrl, temporaryFile)
                    if (destination.exists() && !destination.delete()) {
                        throw IllegalStateException("Could not replace the existing book file.")
                    }
                    if (!temporaryFile.renameTo(destination)) {
                        throw IllegalStateException("Could not save the downloaded book.")
                    }
                    runOnUiThread {
                        downloadProgressSink?.success(
                            mapOf("received" to totalBytes, "total" to totalBytes),
                        )
                        result.success(totalBytes)
                    }
                } catch (error: Exception) {
                    temporaryFile.delete()
                    runOnUiThread {
                        result.error("download_failed", error.message, null)
                    }
                }
            }
        }
    }

    private fun downloadToFile(downloadUrl: String, destination: File): Long {
        var currentUrl = URL(downloadUrl)
        var connection: HttpURLConnection? = null
        try {
            repeat(6) { redirectCount ->
                if (!isGutenbergUrl(currentUrl.toString())) {
                    throw IllegalStateException("Book download redirected to an unsupported host.")
                }
                val request = currentUrl.openConnection() as HttpURLConnection
                connection = request
                request.instanceFollowRedirects = false
                request.connectTimeout = 20000
                request.readTimeout = 30000
                request.setRequestProperty("User-Agent", "OpenLeaf eBook Reader")
                val status = request.responseCode
                if (status in 300..399) {
                    val location = request.getHeaderField("Location")
                        ?: throw IllegalStateException("Book download redirect had no destination.")
                    request.disconnect()
                    if (redirectCount == 5) {
                        throw IllegalStateException("Book download exceeded redirect limit.")
                    }
                    currentUrl = URL(currentUrl, location)
                } else {
                    if (status !in 200..299) {
                        throw IllegalStateException("Book download returned HTTP $status.")
                    }
                    val contentType = request.contentType?.substringBefore(";")?.trim()
                    if (contentType != null &&
                        contentType != "application/epub+zip" &&
                        contentType != "application/octet-stream"
                    ) {
                        throw IllegalStateException("The server did not return an EPUB file.")
                    }

                    val expectedBytes = request.contentLengthLong
                    var receivedBytes = 0L
                    var lastReportedBytes = 0L
                    request.inputStream.buffered().use { input ->
                        destination.outputStream().buffered().use { output ->
                            val buffer = ByteArray(32768)
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                output.write(buffer, 0, count)
                                receivedBytes += count
                                if (receivedBytes - lastReportedBytes >= 256 * 1024) {
                                    lastReportedBytes = receivedBytes
                                    val event = mapOf(
                                        "received" to receivedBytes,
                                        "total" to expectedBytes,
                                    )
                                    runOnUiThread {
                                        downloadProgressSink?.success(event)
                                    }
                                }
                            }
                        }
                    }
                    if (receivedBytes < 4) {
                        throw IllegalStateException("The downloaded EPUB is empty or incomplete.")
                    }
                    destination.inputStream().use { input ->
                        if (input.read() != 0x50 || input.read() != 0x4b) {
                            throw IllegalStateException("The downloaded file is not a valid EPUB archive.")
                        }
                    }
                    return receivedBytes
                }
            }
            throw IllegalStateException("Could not download the book.")
        } finally {
            connection?.disconnect()
        }
    }

    private fun isGutenbergUrl(value: String): Boolean {
        val uri = Uri.parse(value)
        val host = uri.host ?: return false
        return uri.scheme == "https" &&
            (host == "gutenberg.org" || host.endsWith(".gutenberg.org"))
    }

    private fun isAppPrivatePath(value: String): Boolean {
        val root = File(applicationInfo.dataDir).canonicalPath + File.separator
        val destination = File(value).canonicalPath
        return destination.startsWith(root) && destination.endsWith(".epub")
    }

    override fun onDestroy() {
        coverExecutor.shutdownNow()
        super.onDestroy()
    }
}