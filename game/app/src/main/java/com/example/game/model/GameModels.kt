package com.example.game.model

import kotlin.math.sqrt

/**
 * 3D Vector with essential vector mathematics.
 */
data class Vec3(
    val x: Float = 0f,
    val y: Float = 0f,
    val z: Float = 0f
) {
    operator fun plus(other: Vec3): Vec3 = Vec3(x + other.x, y + other.y, z + other.z)
    operator fun minus(other: Vec3): Vec3 = Vec3(x - other.x, y - other.y, z - other.z)
    operator fun times(scale: Float): Vec3 = Vec3(x * scale, y * scale, z * scale)
    operator fun div(scale: Float): Vec3 = if (scale != 0f) Vec3(x / scale, y / scale, z / scale) else this

    fun length(): Float = sqrt(x * x + y * y + z * z)
    fun lengthSq(): Float = x * x + y * y + z * z

    fun normalized(): Vec3 {
        val len = length()
        return if (len > 0.0001f) this / len else Vec3(0f, 0f, 0f)
    }

    fun distanceTo(other: Vec3): Float = (this - other).length()

    companion object {
        val ZERO = Vec3(0f, 0f, 0f)
        val UP = Vec3(0f, 1f, 0f)
    }
}

/**
 * Axis-Aligned Bounding Box for arena colliders.
 */
data class AABB(
    val minX: Float,
    val minY: Float,
    val minZ: Float,
    val maxX: Float,
    val maxY: Float,
    val maxZ: Float
) {
    fun contains(point: Vec3): Boolean {
        return point.x in minX..maxX &&
                point.y in minY..maxY &&
                point.z in minZ..maxZ
    }

    fun intersects(other: AABB): Boolean {
        return (minX <= other.maxX && maxX >= other.minX) &&
                (minY <= other.maxY && maxY >= other.minY) &&
                (minZ <= other.maxZ && maxZ >= other.minZ)
    }
}

/**
 * Procedural player colors from Python Ursina palette.
 */
object GamePalette {
    val COLOR_PALETTE = linkedMapOf(
        "Blue" to 0xFF3498DB,
        "Green" to 0xFF2ECC71,
        "Orange" to 0xFFE67E22,
        "Purple" to 0xFF9B59B6,
        "Yellow" to 0xFFF1C40F,
        "Red" to 0xFFE74C3C,
        "Turquoise" to 0xFF1ABC9C,
        "Pink" to 0xFFEC407A,
        "Cyan" to 0xFF00BCD4,
        "Lime" to 0xFF8BC34A
    )

    val COLOR_NAMES = COLOR_PALETTE.keys.toList()
    val COLOR_VALUES = COLOR_PALETTE.values.toList()

    fun getPlayerColor(identifier: String, username: String? = null): Long {
        if (!username.isNullOrBlank()) {
            val cleanName = username.trim().lowercase()
            for ((cname, color) in COLOR_PALETTE) {
                if (cname.lowercase() == cleanName) return color
            }
            for ((cname, color) in COLOR_PALETTE) {
                if (cleanName.contains(cname.lowercase())) return color
            }
        }
        val idNum = identifier.toIntOrNull()
        if (idNum != null && idNum > 0) {
            val idx = (idNum - 1) % COLOR_VALUES.size
            return COLOR_VALUES[idx]
        }
        val key = username ?: identifier
        val idx = kotlin.math.abs(key.hashCode()) % COLOR_VALUES.size
        return COLOR_VALUES[idx]
    }

    fun colorToFloats(argb: Long): FloatArray {
        val r = ((argb shr 16) and 0xFF) / 255f
        val g = ((argb shr 8) and 0xFF) / 255f
        val b = (argb and 0xFF) / 255f
        val a = ((argb shr 24) and 0xFF) / 255f
        return floatArrayOf(r, g, b, if (a == 0f) 1f else a)
    }
}

/**
 * Bullet representation matching Python bullet physics.
 */
data class Bullet(
    val id: String,
    var position: Vec3,
    val velocity: Vec3,
    val directionY: Float,
    val directionX: Float,
    val damage: Int,
    val shooterId: String,
    var lifetime: Float = 2.0f,
    var isDestroyed: Boolean = false
)

/**
 * Remote / Bot player representation.
 */
data class RemotePlayer(
    val id: String,
    val username: String,
    var position: Vec3,
    var targetPosition: Vec3 = position,
    var rotationY: Float = 0f,
    var health: Float = 250f,
    val maxHealth: Float = 250f,
    val colorArgb: Long = GamePalette.getPlayerColor(id, username),
    var isDead: Boolean = false,
    var kills: Int = 0,
    var deaths: Int = 0,
    var isBot: Boolean = false
)

/**
 * Kill feed entry.
 */
data class KillFeedEntry(
    val id: Long = System.currentTimeMillis() + (0..9999).random(),
    val killerName: String,
    val killerColor: Long,
    val victimName: String,
    val victimColor: Long,
    val timestamp: Long = System.currentTimeMillis()
)
