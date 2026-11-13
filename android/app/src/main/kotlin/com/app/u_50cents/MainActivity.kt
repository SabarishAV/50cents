package com.app.u_50cents

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "com.app.u_50cents/upi_apps"
        const val ICON_SIZE = 96
    }

    /// Listing apps renders a PNG for every icon, which is far too slow for the
    /// UI thread. Work happens here and the reply is posted back to the main
    /// thread.
    private val iconExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "listUpiApps" -> iconExecutor.execute {
                    val apps = try {
                        listUpiApps()
                    } catch (_: Throwable) {
                        emptyList()
                    }
                    mainHandler.post { result.success(apps) }
                }
                "launchUpi" -> {
                    val url = call.argument<String>("url")
                    val packageName = call.argument<String>("packageName")
                    result.success(launchUpi(url, packageName))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        iconExecutor.shutdown()
        super.onDestroy()
    }

    /// Every app installed on the device that can handle a `upi://pay` intent.
    ///
    /// Visibility is granted by the `<queries>` entry in AndroidManifest.xml,
    /// so no QUERY_ALL_PACKAGES permission is needed. Results are de-duplicated
    /// by package name and sorted by their display label.
    private fun listUpiApps(): List<Map<String, Any?>> {
        val pm = applicationContext.packageManager
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay"))

        val resolved = try {
            pm.queryIntentActivities(intent, 0)
        } catch (_: Throwable) {
            return emptyList()
        }

        val seen = HashSet<String>()
        val apps = ArrayList<Map<String, Any?>>()

        for (info in resolved) {
            val packageName = info.activityInfo?.packageName ?: continue
            if (!seen.add(packageName)) continue

            val label = try {
                info.loadLabel(pm).toString().trim()
            } catch (_: Throwable) {
                ""
            }

            val icon = try {
                iconToBase64(info.loadIcon(pm))
            } catch (_: Throwable) {
                null
            }

            apps.add(
                mapOf(
                    "packageName" to packageName,
                    "label" to label.ifEmpty { packageName },
                    "icon" to icon,
                ),
            )
        }

        return apps.sortedBy { it["label"] as String }
    }

    /// Launches a UPI intent, optionally forced to a single app.
    ///
    /// When [packageName] is set the intent is delivered to exactly that app
    /// (no system chooser), which is how we know which app completed the
    /// payment.
    private fun launchUpi(url: String?, packageName: String?): Boolean {
        if (url.isNullOrBlank()) return false
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            if (!packageName.isNullOrBlank()) intent.setPackage(packageName)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    /// Renders any [Drawable] (including adaptive icons) to a square PNG and
    /// returns it base64-encoded so Flutter can show the real app icon.
    private fun iconToBase64(drawable: Drawable): String? {
        val bitmap = Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, ICON_SIZE, ICON_SIZE)
        drawable.draw(canvas)

        val stream = ByteArrayOutputStream()
        if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) return null
        return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    }
}
