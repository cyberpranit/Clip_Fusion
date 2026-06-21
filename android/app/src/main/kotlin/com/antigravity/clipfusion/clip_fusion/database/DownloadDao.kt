package com.antigravity.clipfusion.clip_fusion.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update

@Dao
interface DownloadDao {
    @Query("SELECT * FROM downloads ORDER BY downloadDate DESC")
    suspend fun getAllDownloads(): List<DownloadEntity>

    @Query("SELECT * FROM downloads WHERE favoriteState = 1 ORDER BY downloadDate DESC")
    suspend fun getFavoriteDownloads(): List<DownloadEntity>

    @Query("SELECT * FROM downloads WHERE id = :id")
    suspend fun getDownloadById(id: String): DownloadEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDownload(download: DownloadEntity)

    @Update
    suspend fun updateDownload(download: DownloadEntity)

    @Query("DELETE FROM downloads WHERE id = :id")
    suspend fun deleteDownloadById(id: String)

    @Query("UPDATE downloads SET favoriteState = :favoriteState WHERE id = :id")
    suspend fun updateFavoriteState(id: String, favoriteState: Boolean)

    @Query("UPDATE downloads SET title = :title, filePath = :filePath WHERE id = :id")
    suspend fun renameDownload(id: String, title: String, filePath: String)

    @Query("UPDATE downloads SET status = :status, progress = :progress, speed = :speed, eta = :eta, filePath = :filePath, fileSize = :fileSize WHERE id = :id")
    suspend fun updateProgress(id: String, status: String, progress: Int, speed: String, eta: String, filePath: String?, fileSize: Long)
}
