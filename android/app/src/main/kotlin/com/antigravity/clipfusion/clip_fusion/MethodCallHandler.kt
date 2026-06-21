package com.antigravity.clipfusion.clip_fusion

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.util.Log
import com.antigravity.clipfusion.clip_fusion.database.DownloadDatabase
import com.antigravity.clipfusion.clip_fusion.database.DownloadEntity
import com.antigravity.clipfusion.clip_fusion.download.DownloadForegroundService
import com.antigravity.clipfusion.clip_fusion.whatsapp.WhatsAppStatusSaver
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MethodCallHandler(private val activity: Activity) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val scope = CoroutineScope(Dispatchers.Main)
    private var eventSink: EventChannel.EventSink? = null
    private val whatsappStatusSaver = WhatsAppStatusSaver(activity)

    init {
        // Set up the static progress listener from the Foreground Service
        DownloadForegroundService.progressListener = { id, progress, speed, eta, status ->
            activity.runOnUiThread {
                val map = mapOf(
                    "id" to id,
                    "progress" to progress,
                    "speed" to speed,
                    "eta" to eta,
                    "status" to status
                )
                eventSink?.success(map)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val db = DownloadDatabase.getDatabase(activity.applicationContext)
        val dao = db.downloadDao()

        when (call.method) {
            "updateYoutubeDL" -> {
                scope.launch {
                    try {
                        val status = withContext(Dispatchers.IO) {
                            try {
                                YoutubeDL.getInstance().init(activity.applicationContext)
                            } catch (e: Exception) {
                                // Ignore init errors
                            }
                            YoutubeDL.getInstance().updateYoutubeDL(activity.applicationContext, YoutubeDL.UpdateChannel.STABLE)
                        }
                        result.success(status?.name ?: "DONE")
                    } catch (e: Exception) {
                        Log.e("MethodCallHandler", "updateYoutubeDL failed: ${e.message}")
                        result.error("UPDATE_FAILED", e.message, null)
                    }
                }
            }
            "getVideoInfo" -> {
                val url = call.argument<String>("url")
                if (url == null) {
                    result.error("INVALID_ARGUMENT", "URL is null", null)
                    return
                }
                scope.launch {
                    try {
                        val videoInfo = withContext(Dispatchers.IO) {
                            // Run metadata extraction via youtubedl-android
                            try {
                                YoutubeDL.getInstance().init(activity.applicationContext)
                            } catch (e: Exception) {
                                // Already initialized or error
                            }
                            val request = YoutubeDLRequest(url)
                            YoutubeDL.getInstance().getInfo(request)
                        }

                        // Map formats list
                        val formats = mutableListOf<Map<String, Any?>>()
                        videoInfo.formats?.forEach { format ->
                            formats.add(mapOf(
                                "formatId" to (format.formatId ?: ""),
                                "ext" to (format.ext ?: ""),
                                "height" to format.height,
                                "width" to format.width,
                                "note" to (format.formatNote ?: ""),
                                "fps" to format.fps,
                                "filesize" to format.fileSize
                            ))
                        }

                        val infoMap = mapOf(
                            "id" to (videoInfo.id ?: url.hashCode().toString()),
                            "title" to (videoInfo.title ?: "Media File"),
                            "thumbnail" to (videoInfo.thumbnail ?: ""),
                            "duration" to videoInfo.duration,
                            "uploader" to (videoInfo.uploader ?: videoInfo.uploaderId ?: "Unknown"),
                            "formats" to formats
                        )
                        result.success(infoMap)
                    } catch (e: Exception) {
                        Log.e("MethodCallHandler", "getVideoInfo failed: ${e.message}")
                        result.error("DOWNLOAD_ENGINE_ERROR", e.message, null)
                    }
                }
            }
            "startDownload" -> {
                val id = call.argument<String>("id")
                val url = call.argument<String>("url")
                val outputPath = call.argument<String>("outputPath")
                val formatId = call.argument<String>("formatId") ?: "best"
                val isAudioOnly = call.argument<Boolean>("isAudioOnly") ?: false
                val title = call.argument<String>("title") ?: "Download"
                val platform = call.argument<String>("platform") ?: "unknown"
                val thumbnail = call.argument<String>("thumbnail") ?: ""
                val duration = call.argument<Int>("duration")?.toLong() ?: 0L

                if (id == null || url == null || outputPath == null) {
                    result.error("INVALID_ARGUMENT", "Missing download parameters", null)
                    return
                }

                val intent = Intent(activity, DownloadForegroundService::class.java).apply {
                    action = DownloadForegroundService.ACTION_START
                    putExtra(DownloadForegroundService.EXTRA_ID, id)
                    putExtra(DownloadForegroundService.EXTRA_URL, url)
                    putExtra(DownloadForegroundService.EXTRA_OUTPUT_PATH, outputPath)
                    putExtra(DownloadForegroundService.EXTRA_FORMAT_ID, formatId)
                    putExtra(DownloadForegroundService.EXTRA_IS_AUDIO_ONLY, isAudioOnly)
                    putExtra(DownloadForegroundService.EXTRA_TITLE, title)
                    putExtra(DownloadForegroundService.EXTRA_PLATFORM, platform)
                    putExtra(DownloadForegroundService.EXTRA_THUMBNAIL, thumbnail)
                    putExtra(DownloadForegroundService.EXTRA_DURATION, duration)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.startForegroundService(intent)
                } else {
                    activity.startService(intent)
                }
                result.success(true)
            }
            "pauseDownload" -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error("INVALID_ARGUMENT", "ID is null", null)
                    return
                }
                val intent = Intent(activity, DownloadForegroundService::class.java).apply {
                    action = DownloadForegroundService.ACTION_PAUSE
                    putExtra(DownloadForegroundService.EXTRA_ID, id)
                }
                activity.startService(intent)
                result.success(true)
            }
            "cancelDownload" -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error("INVALID_ARGUMENT", "ID is null", null)
                    return
                }
                val intent = Intent(activity, DownloadForegroundService::class.java).apply {
                    action = DownloadForegroundService.ACTION_CANCEL
                    putExtra(DownloadForegroundService.EXTRA_ID, id)
                }
                activity.startService(intent)
                result.success(true)
            }
            "getDownloads" -> {
                scope.launch {
                    val list = dao.getAllDownloads()
                    val resultList = list.map { it.toMap() }
                    result.success(resultList)
                }
            }
            "getFavorites" -> {
                scope.launch {
                    val list = dao.getFavoriteDownloads()
                    val resultList = list.map { it.toMap() }
                    result.success(resultList)
                }
            }
            "toggleFavorite" -> {
                val id = call.argument<String>("id")
                val favorite = call.argument<Boolean>("favoriteState")
                if (id == null || favorite == null) {
                    result.error("INVALID_ARGUMENT", "ID or favoriteState is null", null)
                    return
                }
                scope.launch {
                    dao.updateFavoriteState(id, favorite)
                    result.success(true)
                }
            }
            "renameDownload" -> {
                val id = call.argument<String>("id")
                val title = call.argument<String>("title")
                val filePath = call.argument<String>("filePath")
                if (id == null || title == null || filePath == null) {
                    result.error("INVALID_ARGUMENT", "Parameters missing for rename", null)
                    return
                }
                scope.launch {
                    dao.renameDownload(id, title, filePath)
                    result.success(true)
                }
            }
            "deleteDownload" -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error("INVALID_ARGUMENT", "ID is null", null)
                    return
                }
                scope.launch {
                    dao.deleteDownloadById(id)
                    result.success(true)
                }
            }
            "getSAFPermissionIntent" -> {
                val intent = WhatsAppStatusSaver.getSAFPermissionIntent()
                activity.startActivityForResult(intent, 54321) // We can handle response in MainActivity if we want
                result.success(true)
            }
            "getWhatsAppStatuses" -> {
                val treeUri = call.argument<String>("treeUri")
                if (treeUri == null) {
                    result.error("INVALID_ARGUMENT", "treeUri is null", null)
                    return
                }
                scope.launch(Dispatchers.IO) {
                    val statuses = whatsappStatusSaver.getStatuses(treeUri)
                    withContext(Dispatchers.Main) {
                        result.success(statuses)
                    }
                }
            }
            "saveWhatsAppStatus" -> {
                val fileUri = call.argument<String>("fileUri")
                if (fileUri == null) {
                    result.error("INVALID_ARGUMENT", "fileUri is null", null)
                    return
                }
                scope.launch(Dispatchers.IO) {
                    val path = whatsappStatusSaver.saveStatus(fileUri)
                    withContext(Dispatchers.Main) {
                        if (path != null) {
                            result.success(path)
                        } else {
                            result.error("SAVE_FAILED", "Failed to save status file", null)
                        }
                    }
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    // Helper extension to map Room Entities to standard Map objects for MethodChannel
    private fun DownloadEntity.toMap(): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "url" to url,
            "title" to title,
            "thumbnail" to thumbnail,
            "duration" to duration,
            "fileSize" to fileSize,
            "platform" to platform,
            "downloadDate" to downloadDate,
            "favoriteState" to favoriteState,
            "status" to status,
            "filePath" to filePath,
            "progress" to progress,
            "speed" to speed,
            "eta" to eta
        )
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }
}
