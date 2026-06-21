package com.antigravity.clipfusion.clip_fusion.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "downloads")
data class DownloadEntity(
    @PrimaryKey val id: String, // unique URL hash or custom ID
    val url: String,
    val title: String,
    val thumbnail: String,
    val duration: Long, // duration in seconds
    val fileSize: Long, // file size in bytes
    val platform: String, // e.g. youtube, instagram, tiktok, facebook, twitter, whatsapp
    val downloadDate: Long, // timestamp
    val favoriteState: Boolean = false,
    val status: String, // PENDING, DOWNLOADING, PAUSED, COMPLETED, FAILED
    val filePath: String?,
    val progress: Int = 0,
    val speed: String = "",
    val eta: String = ""
)
