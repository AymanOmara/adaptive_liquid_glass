package com.aymanomara.adaptive_liquid_glass

import java.io.InputStream
import java.io.OutputStream
import java.util.concurrent.CancellationException
import java.util.concurrent.TimeUnit

/** Set from the main thread by `cancelPhotoImport`; read by the import and codec threads. */
internal class ImportCancel {
    @Volatile
    var cancelled = false

    fun check() {
        if (cancelled) throw CancellationException("Photo import cancelled.")
    }
}

/**
 * Sends `progress` events at most every [intervalNanos], and always one
 * final event per item, so Dart never misses a completion.
 */
internal class ProgressThrottle(
    private val total: Int,
    private val intervalNanos: Long = TimeUnit.MILLISECONDS.toNanos(100),
    private val now: () -> Long = System::nanoTime,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private var completed = 0
    private var last = Long.MIN_VALUE

    @Synchronized
    fun update(index: Int, itemFraction: Double?) {
        val t = now()
        if (last != Long.MIN_VALUE && t - last < intervalNanos) return
        last = t
        emit(event(index, itemFraction))
    }

    @Synchronized
    fun finish(index: Int) {
        completed++
        last = now()
        emit(event(index, 1.0))
    }

    private fun event(index: Int, itemFraction: Double?) = buildMap<String, Any?> {
        put("index", index)
        put("total", total)
        put("completed", completed)
        if (itemFraction != null) put("itemFraction", itemFraction)
    }
}

/** A copy that can be stopped between 256 KiB chunks and reports its fraction. */
internal object ChunkedCopy {
    const val CHUNK = 256 * 1024

    fun copy(
        input: InputStream,
        output: OutputStream,
        size: Long?,
        cancel: ImportCancel,
        onFraction: (Double?) -> Unit,
        onChunk: () -> Unit = {},
    ) {
        val buffer = ByteArray(CHUNK)
        var copied = 0L
        while (true) {
            cancel.check()
            val n = input.read(buffer)
            if (n < 0) break
            output.write(buffer, 0, n)
            copied += n
            onChunk()
            onFraction(if (size != null && size > 0) minOf(1.0, copied.toDouble() / size) else null)
        }
        if (copied == 0L) onFraction(if (size != null && size > 0) 1.0 else null)
    }
}

/** One `pickPhotos` import: its cancel flag, progress and codec quarantine. */
internal class PhotoImportJob(
    val name: String?,
    total: Int,
    emit: (Map<String, Any?>) -> Unit,
    private val supervisor: CodecSupervisor = CodecSupervisor.shared,
) {
    val cancel = ImportCancel()
    val progress = ProgressThrottle(total, emit = emit)

    /** After a codec was abandoned, the rest of this import skips conversion. */
    @Volatile
    var quarantined = false
        private set

    /** Null when conversion is skipped (quarantined) or the codec was abandoned. */
    fun <T> convert(activity: TranscodeProgress, work: () -> T): T? {
        if (quarantined) return null
        return try {
            supervisor.run(cancel, activity, { quarantined = true }, work)
        } catch (e: CodecAbandonedException) {
            quarantined = true
            null
        }
    }

    /** Supervised I/O: throws on abandon and does not quarantine. */
    fun <T> io(activity: TranscodeProgress, work: () -> T): T = supervisor.run(cancel, activity, work = work)
}
