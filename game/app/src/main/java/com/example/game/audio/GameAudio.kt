package com.example.game.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.sin
import kotlin.random.Random

/**
 * Low-latency procedural audio engine and haptic feedback.
 * Synthesizes gunshots, impacts, kills, and respawn cues via AudioTrack PCM buffers.
 */
class GameAudio(private val context: Context) {

    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
        manager?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

    private val soundBuffers = ConcurrentHashMap<String, ShortArray>()
    private val scope = CoroutineScope(Dispatchers.Default)

    var soundEnabled: Boolean = true
    var hapticEnabled: Boolean = true

    init {
        scope.launch {
            generateSounds()
        }
    }

    private fun generateSounds() {
        val sampleRate = 22050

        // 1. Gunshot sound: Sharp transient pop + decaying white noise burst
        val gunshotSamples = (sampleRate * 0.18f).toInt()
        val gunshot = ShortArray(gunshotSamples)
        for (i in 0 until gunshotSamples) {
            val progress = i.toFloat() / gunshotSamples
            val decay = (1f - progress) * (1f - progress)
            val noise = (Random.nextFloat() * 2f - 1f) * 0.7f
            val punchFreq = 180f * (1f - progress * 0.8f)
            val punch = sin(2.0 * Math.PI * punchFreq * i / sampleRate).toFloat() * 0.5f
            val mixed = (noise + punch) * decay
            gunshot[i] = (mixed.coerceIn(-1f, 1f) * Short.MAX_VALUE * 0.9f).toInt().toShort()
        }
        soundBuffers["gunshot"] = gunshot

        // 2. Hit marker sound: Crisp, high-frequency double click
        val hitSamples = (sampleRate * 0.07f).toInt()
        val hit = ShortArray(hitSamples)
        for (i in 0 until hitSamples) {
            val progress = i.toFloat() / hitSamples
            val decay = 1f - progress
            val tone = sin(2.0 * Math.PI * 1850.0 * i / sampleRate).toFloat()
            hit[i] = (tone * decay * Short.MAX_VALUE * 0.7f).toInt().toShort()
        }
        soundBuffers["hit"] = hit

        // 3. Player damage sound: Low punch
        val damageSamples = (sampleRate * 0.15f).toInt()
        val damage = ShortArray(damageSamples)
        for (i in 0 until damageSamples) {
            val progress = i.toFloat() / damageSamples
            val decay = (1f - progress)
            val tone = sin(2.0 * Math.PI * (120f - progress * 40f) * i / sampleRate).toFloat()
            val noise = (Random.nextFloat() * 2f - 1f) * 0.3f
            damage[i] = ((tone + noise) * decay * Short.MAX_VALUE * 0.8f).toInt().toShort()
        }
        soundBuffers["damage"] = damage

        // 4. Kill confirmation: Ascending chime
        val killSamples = (sampleRate * 0.25f).toInt()
        val kill = ShortArray(killSamples)
        for (i in 0 until killSamples) {
            val progress = i.toFloat() / killSamples
            val freq = if (progress < 0.5f) 523.25 else 784.0 // C5 -> G5
            val tone = sin(2.0 * Math.PI * freq * i / sampleRate).toFloat()
            val decay = 1f - progress
            kill[i] = (tone * decay * Short.MAX_VALUE * 0.65f).toInt().toShort()
        }
        soundBuffers["kill"] = kill

        // 5. Respawn chime: Futuristic ascending warp tone
        val respawnSamples = (sampleRate * 0.35f).toInt()
        val respawn = ShortArray(respawnSamples)
        for (i in 0 until respawnSamples) {
            val progress = i.toFloat() / respawnSamples
            val freq = 300.0 + progress * 600.0
            val tone = sin(2.0 * Math.PI * freq * i / sampleRate).toFloat()
            val envelope = if (progress < 0.2f) progress / 0.2f else (1f - progress) / 0.8f
            respawn[i] = (tone * envelope * Short.MAX_VALUE * 0.6f).toInt().toShort()
        }
        soundBuffers["respawn"] = respawn
    }

    private fun playSound(soundName: String, volume: Float = 1.0f) {
        if (!soundEnabled) return
        val buffer = soundBuffers[soundName] ?: return
        scope.launch {
            try {
                val sampleRate = 22050
                val track = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_GAME)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(buffer.size * 2)
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()

                track.setVolume(volume.coerceIn(0f, 1f))
                track.write(buffer, 0, buffer.size)
                track.play()
                // Let it play out then release
                launch(Dispatchers.IO) {
                    Thread.sleep((buffer.size * 1000L) / sampleRate + 50)
                    track.stop()
                    track.release()
                }
            } catch (_: Exception) {
            }
        }
    }

    fun playGunshot() {
        playSound("gunshot", 0.9f)
        vibrate(35)
    }

    fun playHitMarker() {
        playSound("hit", 0.8f)
    }

    fun playDamageTaken() {
        playSound("damage", 1.0f)
        vibrate(75)
    }

    fun playKill() {
        playSound("kill", 0.9f)
        vibrate(100)
    }

    fun playRespawn() {
        playSound("respawn", 0.8f)
    }

    private fun vibrate(durationMs: Long) {
        if (!hapticEnabled || vibrator == null || !vibrator.hasVibrator()) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(durationMs)
            }
        } catch (_: Exception) {
        }
    }
}
