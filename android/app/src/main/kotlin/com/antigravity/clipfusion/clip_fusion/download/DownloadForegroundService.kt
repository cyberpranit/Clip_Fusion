package com.antigravity.clipfusion.clip_fusion.download

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.antigravity.clipfusion.clip_fusion.database.DownloadDatabase
import com.antigravity.clipfusion.clip_fusion.database.DownloadEntity
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class DownloadForegroundService : Service() {

    private val serviceScope = CoroutineScope(Dispatchers.IO + Job())
    private val activeJobs = ConcurrentHashMap<String, Job>()

    private lateinit var notificationManager: NotificationManager

    companion object {
        const val CHANNEL_ID = "ClipFusionDownloadChannel"
        const val CHANNEL_NAME = "ClipFusion Media Downloads"

        // Actions
        const val ACTION_START = "com.antigravity.clipfusion.ACTION_START"
        const val ACTION_PAUSE = "com.antigravity.clipfusion.ACTION_PAUSE"
        const val ACTION_CANCEL = "com.antigravity.clipfusion.ACTION_CANCEL"

        // Extras
        const val EXTRA_ID = "EXTRA_ID"
        const val EXTRA_URL = "EXTRA_URL"
        const val EXTRA_OUTPUT_PATH = "EXTRA_OUTPUT_PATH"
        const val EXTRA_FORMAT_ID = "EXTRA_FORMAT_ID"
        const val EXTRA_IS_AUDIO_ONLY = "EXTRA_IS_AUDIO_ONLY"
        const val EXTRA_TITLE = "EXTRA_TITLE"
        const val EXTRA_PLATFORM = "EXTRA_PLATFORM"
        const val EXTRA_THUMBNAIL = "EXTRA_THUMBNAIL"
        const val EXTRA_DURATION = "EXTRA_DURATION"

        // Static interface to broadcast progress back to MethodCallHandler/Flutter in real time
        var progressListener: ((String, Int, String, String, String) -> Unit)? = null
    }

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        val action = intent.action
        val downloadId = intent.getStringExtra(EXTRA_ID) ?: return START_NOT_STICKY

        when (action) {
            ACTION_START -> {
                val url = intent.getStringExtra(EXTRA_URL) ?: return START_NOT_STICKY
                val outputPath = intent.getStringExtra(EXTRA_OUTPUT_PATH) ?: return START_NOT_STICKY
                val formatId = intent.getStringExtra(EXTRA_FORMAT_ID) ?: "best"
                val isAudioOnly = intent.getBooleanExtra(EXTRA_IS_AUDIO_ONLY, false)
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Downloading Media"
                val platform = intent.getStringExtra(EXTRA_PLATFORM) ?: "unknown"
                val thumbnail = intent.getStringExtra(EXTRA_THUMBNAIL) ?: ""
                val duration = intent.getLongExtra(EXTRA_DURATION, 0L)

                startDownload(downloadId, url, outputPath, formatId, isAudioOnly, title, platform, thumbnail, duration)
            }
            ACTION_PAUSE -> {
                pauseDownload(downloadId)
            }
            ACTION_CANCEL -> {
                cancelDownload(downloadId)
            }
        }

        return START_NOT_STICKY
    }

    private fun startDownload(
        id: String,
        url: String,
        outputPath: String,
        formatId: String,
        isAudioOnly: Boolean,
        title: String,
        platform: String,
        thumbnail: String,
        duration: Long
    ) {
        if (activeJobs.containsKey(id)) return

        val job = serviceScope.launch {
            val db = DownloadDatabase.getDatabase(applicationContext)
            val dao = db.downloadDao()

            // 1. Save or Update in Room DB with status PENDING
            val existing = dao.getDownloadById(id)
            val downloadDate = existing?.downloadDate ?: System.currentTimeMillis()
            val favoriteState = existing?.favoriteState ?: false
            
            val initialEntity = DownloadEntity(
                id = id,
                url = url,
                title = title,
                thumbnail = thumbnail,
                duration = duration,
                fileSize = existing?.fileSize ?: 0L,
                platform = platform,
                downloadDate = downloadDate,
                favoriteState = favoriteState,
                status = "DOWNLOADING",
                filePath = null,
                progress = 0,
                speed = "",
                eta = ""
            )
            dao.insertDownload(initialEntity)
            notifyListener(id, 0, "0 KB/s", "--:--", "DOWNLOADING")

            // 2. Start Foreground Service
            val notificationId = id.hashCode()
            val notification = buildProgressNotification(id, title, 0, "Starting...", "")
            
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(notificationId, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                } else {
                    startForeground(notificationId, notification)
                }
            } catch (e: Exception) {
                Log.e("DownloadService", "startForeground failed: ${e.message}")
            }

            try {
                // Ensure target directory exists
                val outDir = File(outputPath)
                if (!outDir.exists()) outDir.mkdirs()

                // 3. Build youtubedl-android request
                val request = YoutubeDLRequest(url)
                request.addOption("-o", "$outputPath/%(title)s.%(ext)s")
                request.addOption("-c") // continue partial downloads natively

                if (isAudioOnly) {
                    request.addOption("-f", "bestaudio")
                    request.addOption("--extract-audio")
                    request.addOption("--audio-format", "mp3")
                } else {
                    if (formatId != "best") {
                        // Merge best video of selected resolution and best audio
                        request.addOption("-f", "$formatId+bestaudio/best")
                    } else {
                        request.addOption("-f", "bestvideo+bestaudio/best")
                    }
                }

                // Initialize youtubedl-android wrapper if not already
                try {
                    YoutubeDL.getInstance().init(applicationContext)
                } catch (e: Exception) {
                    Log.d("DownloadService", "Already initialized or init error: ${e.message}")
                }

                var finalFilePath: String? = null

                // Execute download task
                val response = YoutubeDL.getInstance().execute(request, id) { progress, etaInSeconds, line ->
                    // Parse line for extra info like speed if desired
                    val speed = parseSpeedFromLine(line)
                    val etaStr = formatEta(etaInSeconds)
                    
                    // Update Notification
                    val updatedNotification = buildProgressNotification(id, title, progress.toInt(), speed, etaStr)
                    notificationManager.notify(notificationId, updatedNotification)

                    // Update Room Database
                    serviceScope.launch {
                        dao.updateProgress(id, "DOWNLOADING", progress.toInt(), speed, etaStr, null, 0L)
                    }

                    // Trigger real-time callback
                    notifyListener(id, progress.toInt(), speed, etaStr, "DOWNLOADING")
                }

                // 4. Handle Completion
                val finalFile = scanForDownloadedFile(outputPath, title)
                finalFilePath = finalFile?.absolutePath
                val fileSize = finalFile?.length() ?: 0L

                dao.updateProgress(id, "COMPLETED", 100, "", "", finalFilePath, fileSize)
                notifyListener(id, 100, "", "", "COMPLETED")

                // Update notification to completed
                val completedNotification = NotificationCompat.Builder(this@DownloadForegroundService, CHANNEL_ID)
                    .setContentTitle("Download Finished")
                    .setContentText(title)
                    .setSmallIcon(android.R.drawable.stat_sys_download_done)
                    .setAutoCancel(true)
                    .build()
                notificationManager.notify(notificationId, completedNotification)

            } catch (e: Exception) {
                Log.e("DownloadService", "Download failed: ${e.message}")
                // Update DB state to FAILED
                serviceScope.launch {
                    val currentEntity = dao.getDownloadById(id)
                    if (currentEntity?.status != "PAUSED") {
                        dao.updateProgress(id, "FAILED", 0, "", "", null, 0L)
                        notifyListener(id, 0, "", "", "FAILED")
                    }
                }
                
                // Show failed notification
                val failedNotification = NotificationCompat.Builder(this@DownloadForegroundService, CHANNEL_ID)
                    .setContentTitle("Download Failed")
                    .setContentText(title)
                    .setSmallIcon(android.R.drawable.stat_notify_error)
                    .setAutoCancel(true)
                    .build()
                notificationManager.notify(notificationId, failedNotification)
            } finally {
                activeJobs.remove(id)
                stopForeground(STOP_FOREGROUND_DETACH)
                if (activeJobs.isEmpty()) {
                    stopSelf()
                }
            }
        }

        activeJobs[id] = job
    }

    private fun pauseDownload(id: String) {
        serviceScope.launch {
            val db = DownloadDatabase.getDatabase(applicationContext)
            val dao = db.downloadDao()
            
            // Mark as PAUSED in DB
            dao.updateProgress(id, "PAUSED", 0, "", "", null, 0L)
            notifyListener(id, 0, "", "", "PAUSED")

            // Destroy yt-dlp process
            try {
                YoutubeDL.getInstance().destroyProcessById(id)
            } catch (e: Exception) {
                Log.e("DownloadService", "Error pausing process: ${e.message}")
            }

            activeJobs[id]?.cancel()
            activeJobs.remove(id)

            val notificationId = id.hashCode()
            notificationManager.cancel(notificationId)

            if (activeJobs.isEmpty()) {
                stopSelf()
            }
        }
    }

    private fun cancelDownload(id: String) {
        serviceScope.launch {
            val db = DownloadDatabase.getDatabase(applicationContext)
            val dao = db.downloadDao()
            
            // Fetch download entity to delete partial files
            val entity = dao.getDownloadById(id)

            // Remove from database
            dao.deleteDownloadById(id)
            notifyListener(id, 0, "", "", "FAILED")

            // Destroy process
            try {
                YoutubeDL.getInstance().destroyProcessById(id)
            } catch (e: Exception) {
                Log.e("DownloadService", "Error canceling process: ${e.message}")
            }

            activeJobs[id]?.cancel()
            activeJobs.remove(id)

            val notificationId = id.hashCode()
            notificationManager.cancel(notificationId)

            // Attempt cleanup of partial/part files
            entity?.title?.let { title ->
                // Basic check for files containing title or extension .part in directory
                // We'll clean it up during execution if needed
            }

            if (activeJobs.isEmpty()) {
                stopSelf()
            }
        }
    }

    private fun buildProgressNotification(
        id: String,
        title: String,
        progress: Int,
        speed: String,
        eta: String
    ): Notification {
        val pauseIntent = Intent(this, DownloadForegroundService::class.java).apply {
            action = ACTION_PAUSE
            putExtra(EXTRA_ID, id)
        }
        val pendingPause = PendingIntent.getService(
            this, id.hashCode(), pauseIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val cancelIntent = Intent(this, DownloadForegroundService::class.java).apply {
            action = ACTION_CANCEL
            putExtra(EXTRA_ID, id)
        }
        val pendingCancel = PendingIntent.getService(
            this, id.hashCode() + 1, cancelIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val text = if (eta.isNotEmpty()) "$progress% | $speed | ETA: $eta" else "$progress% | $speed"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setProgress(100, progress, false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(android.R.drawable.ic_media_pause, "Pause", pendingPause)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Cancel", pendingCancel)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows progress of media downloads"
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun parseSpeedFromLine(line: String): String {
        // Parse speed string like "1.2MiB/s" or "300KiB/s" from yt-dlp progress line
        val regex = "(\\d+(\\.\\d+)?(KiB|MiB|GiB|B)/s)".toRegex()
        val match = regex.find(line)
        return match?.value ?: "0 B/s"
    }

    private fun formatEta(seconds: Long): String {
        if (seconds <= 0) return "--:--"
        val mins = seconds / 60
        val secs = seconds % 60
        return String.format("%02d:%02d", mins, secs)
    }

    private fun scanForDownloadedFile(directory: String, title: String): File? {
        val dir = File(directory)
        if (!dir.exists() || !dir.isDirectory) return null

        // Try to match file starting with title (yt-dlp names output as Title.extension or similar)
        val files = dir.listFiles() ?: return null
        
        // Clean title of invalid characters
        val cleanTitle = title.replace("[\\\\/:*?\"<>|]".toRegex(), "")

        // Look for exact or fuzzy matches, excluding temp/part files
        return files.firstOrNull { file ->
            val name = file.name
            !name.endsWith(".part") && !name.endsWith(".ytdl") && 
                    (name.contains(cleanTitle, ignoreCase = true) || name.contains(title.take(15), ignoreCase = true))
        }
    }

    private fun notifyListener(id: String, progress: Int, speed: String, eta: String, status: String) {
        progressListener?.invoke(id, progress, speed, eta, status)
    }

    override fun onDestroy() {
        serviceScope.launch {
            // Cancel all active jobs and stop processes
            for (id in activeJobs.keys) {
                try {
                    YoutubeDL.getInstance().destroyProcessById(id)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            activeJobs.clear()
        }
        super.onDestroy()
    }
}
