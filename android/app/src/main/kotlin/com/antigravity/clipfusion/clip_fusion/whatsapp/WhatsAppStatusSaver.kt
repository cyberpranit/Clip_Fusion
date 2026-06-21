package com.antigravity.clipfusion.clip_fusion.whatsapp

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Environment
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream

class WhatsAppStatusSaver(private val context: Context) {

    companion object {
        const val WHATSAPP_STATUS_DIR = "Android/media/com.whatsapp/WhatsApp/Media/.Statuses"
        
        // Return intent to request SAF permission
        fun getSAFPermissionIntent(): Intent {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
            intent.addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
            // Pre-fill path if possible (only works on Android 8.0+)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val authority = "com.android.externalstorage.documents"
                val documentId = "primary:Android/media/com.whatsapp"
                val treeUri = Uri.parse("content://$authority/tree/${Uri.encode(documentId)}")
                intent.putExtra("android.provider.extra.INITIAL_URI", treeUri)
            }
            return intent
        }
    }

    fun getStatuses(treeUriStr: String): List<Map<String, Any>> {
        val statuses = mutableListOf<Map<String, Any>>()
        try {
            val treeUri = Uri.parse(treeUriStr)
            
            // Take persistable permission just in case
            val contentResolver: ContentResolver = context.contentResolver
            contentResolver.takePersistableUriPermission(
                treeUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )

            val rootDirectory = DocumentFile.fromTreeUri(context, treeUri) ?: return emptyList()
            val directory = findStatusesFolder(rootDirectory) ?: return emptyList()
            val files = directory.listFiles()

            // Prepare cache folder
            val cacheDir = File(context.cacheDir, "whatsapp_statuses_cache")
            if (!cacheDir.exists()) cacheDir.mkdirs()

            for (file in files) {
                val name = file.name ?: continue
                if (file.isFile && (name.endsWith(".mp4") || name.endsWith(".jpg") || name.endsWith(".jpeg") || name.endsWith(".gif"))) {
                    val isVideo = name.endsWith(".mp4")
                    val type = if (isVideo) "video" else "image"
                    
                    // Generate local thumbnail cache
                    val thumbnailFile = File(cacheDir, "${name}_thumb.jpg")
                    var thumbnailPath = ""
                    
                    if (thumbnailFile.exists()) {
                        thumbnailPath = thumbnailFile.absolutePath
                    } else {
                        try {
                            if (isVideo) {
                                val retriever = MediaMetadataRetriever()
                                retriever.setDataSource(context, file.uri)
                                val bitmap = retriever.getFrameAtTime(1000000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                                retriever.release()
                                
                                if (bitmap != null) {
                                    val fos = FileOutputStream(thumbnailFile)
                                    bitmap.compress(Bitmap.CompressFormat.JPEG, 70, fos)
                                    fos.flush()
                                    fos.close()
                                    thumbnailPath = thumbnailFile.absolutePath
                                }
                            } else {
                                val inputStream = context.contentResolver.openInputStream(file.uri)
                                if (inputStream != null) {
                                    val fos = FileOutputStream(thumbnailFile)
                                    val buffer = ByteArray(1024)
                                    var len: Int
                                    while (inputStream.read(buffer).also { len = it } != -1) {
                                        fos.write(buffer, 0, len)
                                    }
                                    fos.flush()
                                    fos.close()
                                    inputStream.close()
                                    thumbnailPath = thumbnailFile.absolutePath
                                }
                            }
                        } catch (e: Exception) {
                            Log.e("WhatsAppStatusSaver", "Failed to cache thumbnail for $name: ${e.message}")
                        }
                    }

                    val map = mapOf(
                        "name" to name,
                        "uri" to file.uri.toString(),
                        "thumbnail" to thumbnailPath,
                        "size" to file.length(),
                        "type" to type,
                        "lastModified" to file.lastModified()
                    )
                    statuses.add(map)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return statuses.sortedByDescending { it["lastModified"] as Long }
    }

    fun saveStatus(fileUriStr: String): String? {
        var inputStream: InputStream? = null
        var outputStream: OutputStream? = null
        try {
            val fileUri = Uri.parse(fileUriStr)
            val document = DocumentFile.fromSingleUri(context, fileUri) ?: return null
            val fileName = document.name ?: "status_${System.currentTimeMillis()}.mp4"

            inputStream = context.contentResolver.openInputStream(fileUri) ?: return null
            
            val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val clipFusionDir = File(downloadDir, "ClipFusion")
            if (!clipFusionDir.exists()) clipFusionDir.mkdirs()

            val targetFile = File(clipFusionDir, fileName)
            outputStream = FileOutputStream(targetFile)

            val buffer = ByteArray(1024)
            var bytesRead: Int
            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                outputStream.write(buffer, 0, bytesRead)
            }
            outputStream.flush()

            return targetFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        } finally {
            inputStream?.close()
            outputStream?.close()
        }
    }

    private fun findStatusesFolder(directory: DocumentFile): DocumentFile? {
        if (directory.name == ".Statuses") {
            return directory
        }

        val paths = listOf(
            listOf("WhatsApp", "Media", ".Statuses"),
            listOf("WhatsApp Business", "Media", ".Statuses"),
            listOf("Media", ".Statuses")
        )

        for (segmentList in paths) {
            var current: DocumentFile? = directory
            for (segment in segmentList) {
                current = current?.findFile(segment)
                if (current == null) break
            }
            if (current != null && current.isDirectory) {
                return current
            }
        }

        // Recursive search fallback
        return findFolderRecursively(directory, ".Statuses", 0)
    }

    private fun findFolderRecursively(directory: DocumentFile, targetName: String, depth: Int): DocumentFile? {
        if (depth > 3) return null
        if (directory.name == targetName) return directory

        try {
            val files = directory.listFiles()
            for (file in files) {
                if (file.isDirectory) {
                    if (file.name == targetName) {
                        return file
                    }
                    val found = findFolderRecursively(file, targetName, depth + 1)
                    if (found != null) return found
                }
            }
        } catch (e: Exception) {
            // Ignore listFiles errors
        }
        return null
    }
}
