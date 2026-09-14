package com.example.game.arena

import com.example.game.model.AABB
import com.example.game.model.Vec3

/**
 * Multi-level arena specifications identical to floor.py and map.py:
 * - 40x40 Ground Floor with checkerboard pattern (y=1.0 standing level)
 * - 1st Floor Upper Deck (Mezzanine at y=6.0 standing level)
 * - East and West staircases with ramp colliders and handrails
 * - 4 Support Pillars, atrium perimeter railings, and tactical barricades
 * - Corner bunkers and center cover blocks
 */
object ArenaMap {
    const val ARENA_HALF_SIZE = 20f
    const val GROUND_Y = 1.0f
    const val UPPER_DECK_Y = 6.0f

    // Spawn points directly from Ursina player.py
    val SPAWN_POINTS = listOf(
        Vec3(0f, 1f, 0f),
        Vec3(12f, 1f, 0f),
        Vec3(0f, 1f, 12f),
        Vec3(12f, 1f, 12f),
        Vec3(-6f, 1f, -6f),
        Vec3(6f, 1f, -6f),
        // 1st Floor upper deck spawns
        Vec3(0f, 6f, 14f),
        Vec3(0f, 6f, -14f),
        Vec3(16f, 6f, 0f),
        Vec3(-16f, 6f, 0f)
    )

    // Solid obstacle bounding boxes (for player collision & bullet hits)
    val OBSTACLES = mutableListOf<AABB>()

    // Decorative / Architectural blocks
    data class Block(
        val center: Vec3,
        val size: Vec3,
        val type: BlockType,
        val colorArgb: Long = 0xFF4A5568
    )

    enum class BlockType {
        WALL, PILLAR, RAILING, BARRICADE, UPPER_SLAB, STAIR_STEP
    }

    val BLOCKS = mutableListOf<Block>()

    init {
        buildArenaGeometry()
    }

    private fun buildArenaGeometry() {
        BLOCKS.clear()
        OBSTACLES.clear()

        // 1. Support Pillars (4 pillars)
        val pillarPositions = listOf(
            Vec3(12f, 3.5f, 6f),
            Vec3(12f, 3.5f, -6f),
            Vec3(-12f, 3.5f, 6f),
            Vec3(-12f, 3.5f, -6f)
        )
        for (pos in pillarPositions) {
            val size = Vec3(1f, 5f, 1f)
            BLOCKS.add(Block(pos, size, BlockType.PILLAR, 0xFF334155))
            addObstacle(pos, size)
        }

        // 2. Upper Deck Mezzanine Slabs (thickness 0.5, top at y=6.0)
        // North platform: X: [-20, 20], Z: [6, 20], center=(0, 5.75, 13)
        BLOCKS.add(Block(Vec3(0f, 5.75f, 13f), Vec3(40f, 0.5f, 14f), BlockType.UPPER_SLAB, 0xFF1E293B))
        // South platform: X: [-20, 20], Z: [-20, -6], center=(0, 5.75, -13)
        BLOCKS.add(Block(Vec3(0f, 5.75f, -13f), Vec3(40f, 0.5f, 14f), BlockType.UPPER_SLAB, 0xFF1E293B))
        // East walkway: X: [12, 20], Z: [-6, 6], center=(16, 5.75, 0)
        BLOCKS.add(Block(Vec3(16f, 5.75f, 0f), Vec3(8f, 0.5f, 12f), BlockType.UPPER_SLAB, 0xFF1E293B))
        // West walkway: X: [-20, -12], Z: [-6, 6], center=(-16, 5.75, 0)
        BLOCKS.add(Block(Vec3(-16f, 5.75f, 0f), Vec3(8f, 0.5f, 12f), BlockType.UPPER_SLAB, 0xFF1E293B))

        // 3. Railings along 1st floor atrium
        // East & West atrium railings
        val atriumRailings = listOf(
            Block(Vec3(12f, 6.5f, 0f), Vec3(0.4f, 1.0f, 12f), BlockType.RAILING, 0xFF475569),
            Block(Vec3(-12f, 6.5f, 0f), Vec3(0.4f, 1.0f, 12f), BlockType.RAILING, 0xFF475569),
            // North atrium railings (leaves stair opening at x=8.5)
            Block(Vec3(-2.625f, 6.5f, 6f), Vec3(18.75f, 1.0f, 0.4f), BlockType.RAILING, 0xFF475569),
            Block(Vec3(11.125f, 6.5f, 6f), Vec3(1.75f, 1.0f, 0.4f), BlockType.RAILING, 0xFF475569),
            // South atrium railings (leaves stair opening at x=-8.5)
            Block(Vec3(2.625f, 6.5f, -6f), Vec3(18.75f, 1.0f, 0.4f), BlockType.RAILING, 0xFF475569),
            Block(Vec3(-11.125f, 6.5f, -6f), Vec3(1.75f, 1.0f, 0.4f), BlockType.RAILING, 0xFF475569)
        )
        for (r in atriumRailings) {
            BLOCKS.add(r)
            addObstacle(r.center, r.size)
        }

        // 4. Upper Floor Tactical Cover Barricades
        val upperBarricades = listOf(
            Block(Vec3(0f, 6.75f, 15f), Vec3(4f, 1.5f, 1.0f), BlockType.BARRICADE, 0xFF0EA5E9),
            Block(Vec3(0f, 6.75f, -15f), Vec3(4f, 1.5f, 1.0f), BlockType.BARRICADE, 0xFF0EA5E9)
        )
        for (b in upperBarricades) {
            BLOCKS.add(b)
            addObstacle(b.center, b.size)
        }

        // 5. Corner Bunkers & Tactical Walls (from map.py)
        val wallsData = listOf(
            // Top-Right (+X, +Z)
            Block(Vec3(16f, 2f, 13f), Vec3(1.5f, 4f, 6f), BlockType.WALL, 0xFF3B82F6),
            Block(Vec3(13f, 2f, 16f), Vec3(6f, 4f, 1.5f), BlockType.WALL, 0xFF3B82F6),
            // Top-Left (-X, +Z)
            Block(Vec3(-16f, 2f, 13f), Vec3(1.5f, 4f, 6f), BlockType.WALL, 0xFF3B82F6),
            Block(Vec3(-13f, 2f, 16f), Vec3(6f, 4f, 1.5f), BlockType.WALL, 0xFF3B82F6),
            // Bottom-Left (-X, -Z)
            Block(Vec3(-16f, 2f, -13f), Vec3(1.5f, 4f, 6f), BlockType.WALL, 0xFF3B82F6),
            Block(Vec3(-13f, 2f, -16f), Vec3(6f, 4f, 1.5f), BlockType.WALL, 0xFF3B82F6),
            // Bottom-Right (+X, -Z)
            Block(Vec3(16f, 2f, -13f), Vec3(1.5f, 4f, 6f), BlockType.WALL, 0xFF3B82F6),
            Block(Vec3(13f, 2f, -16f), Vec3(6f, 4f, 1.5f), BlockType.WALL, 0xFF3B82F6),
            // Perimeter mid-lane covers
            Block(Vec3(-15f, 1.75f, 0f), Vec3(1.5f, 3.5f, 4f), BlockType.WALL, 0xFF64748B),
            Block(Vec3(0f, 1.75f, -15f), Vec3(4f, 3.5f, 1.5f), BlockType.WALL, 0xFF64748B),
            // Center tactical barricades
            Block(Vec3(-4f, 1.5f, 3f), Vec3(3.5f, 3f, 1.2f), BlockType.BARRICADE, 0xFFF97316),
            Block(Vec3(4f, 1.5f, -3f), Vec3(3.5f, 3f, 1.2f), BlockType.BARRICADE, 0xFFF97316)
        )
        for (w in wallsData) {
            BLOCKS.add(w)
            addObstacle(w.center, w.size)
        }

        // 6. Stair Steps for 3D visual fidelity
        // Stair 1 (East flank at x=8.5): z from -3.5 to 5.5, y from 1.25 to 5.75
        for (i in 0 until 10) {
            val stepY = 1.25f + i * 0.5f
            val stepZ = -3.5f + i * 1.0f
            BLOCKS.add(Block(Vec3(8.5f, stepY, stepZ), Vec3(3.5f, 0.5f, 1.0f), BlockType.STAIR_STEP, 0xFF475569))
        }
        // Stair 2 (West flank at x=-8.5): z from 3.5 down to -5.5, y from 1.25 to 5.75
        for (i in 0 until 10) {
            val stepY = 1.25f + i * 0.5f
            val stepZ = 3.5f - i * 1.0f
            BLOCKS.add(Block(Vec3(-8.5f, stepY, stepZ), Vec3(3.5f, 0.5f, 1.0f), BlockType.STAIR_STEP, 0xFF475569))
        }

        // Stair Railings
        BLOCKS.add(Block(Vec3(6.65f, 3.9f, 1.0f), Vec3(0.2f, 0.8f, 11.2f), BlockType.RAILING, 0xFF64748B))
        BLOCKS.add(Block(Vec3(10.35f, 3.9f, 1.0f), Vec3(0.2f, 0.8f, 11.2f), BlockType.RAILING, 0xFF64748B))
        BLOCKS.add(Block(Vec3(-6.65f, 3.9f, -1.0f), Vec3(0.2f, 0.8f, 11.2f), BlockType.RAILING, 0xFF64748B))
        BLOCKS.add(Block(Vec3(-10.35f, 3.9f, -1.0f), Vec3(0.2f, 0.8f, 11.2f), BlockType.RAILING, 0xFF64748B))

        // Outer Perimeter Walls (height 8) to prevent falling outside
        val wallThickness = 1.0f
        val wallHeight = 8.0f
        // North wall
        addObstacle(Vec3(0f, wallHeight / 2, ARENA_HALF_SIZE + wallThickness / 2), Vec3(ARENA_HALF_SIZE * 2 + 2, wallHeight, wallThickness))
        // South wall
        addObstacle(Vec3(0f, wallHeight / 2, -ARENA_HALF_SIZE - wallThickness / 2), Vec3(ARENA_HALF_SIZE * 2 + 2, wallHeight, wallThickness))
        // East wall
        addObstacle(Vec3(ARENA_HALF_SIZE + wallThickness / 2, wallHeight / 2, 0f), Vec3(wallThickness, wallHeight, ARENA_HALF_SIZE * 2 + 2))
        // West wall
        addObstacle(Vec3(-ARENA_HALF_SIZE - wallThickness / 2, wallHeight / 2, 0f), Vec3(wallThickness, wallHeight, ARENA_HALF_SIZE * 2 + 2))
    }

    private fun addObstacle(center: Vec3, size: Vec3) {
        val hx = size.x / 2
        val hy = size.y / 2
        val hz = size.z / 2
        OBSTACLES.add(
            AABB(
                center.x - hx, center.y - hy, center.z - hz,
                center.x + hx, center.y + hy, center.z + hz
            )
        )
    }

    /**
     * Compute ground/standing elevation at position (x, z)
     */
    fun getStandingElevation(x: Float, z: Float): Float {
        // East Staircase corridor: climbs +Z from z=-4 (y=1.0) to z=6 (y=6.0)
        if (x in 6.75f..10.25f && z in -4.0f..6.0f) {
            val progress = (z - (-4.0f)) / 10.0f
            return 1.0f + progress.coerceIn(0f, 1f) * 5.0f
        }

        // West Staircase corridor: climbs -Z from z=4 (y=1.0) to z=-6 (y=6.0)
        if (x in -10.25f..-6.75f && z in -6.0f..4.0f) {
            val progress = (4.0f - z) / 10.0f
            return 1.0f + progress.coerceIn(0f, 1f) * 5.0f
        }

        // Upper Deck Mezzanine checks
        val onNorthDeck = (x in -20f..20f) && (z in 6f..20f)
        val onSouthDeck = (x in -20f..20f) && (z in -20f..-6f)
        val onEastDeck = (x in 12f..20f) && (z in -6f..6f)
        val onWestDeck = (x in -20f..-12f) && (z in -6f..6f)

        if (onNorthDeck || onSouthDeck || onEastDeck || onWestDeck) {
            return UPPER_DECK_Y
        }

        // Default ground floor
        return GROUND_Y
    }

    /**
     * Check if a cylinder / point collides with any solid obstacle.
     */
    fun checkCollision(position: Vec3, radius: Float = 0.5f, height: Float = 1.8f): Boolean {
        // Outer boundaries
        if (position.x - radius < -ARENA_HALF_SIZE || position.x + radius > ARENA_HALF_SIZE ||
            position.z - radius < -ARENA_HALF_SIZE || position.z + radius > ARENA_HALF_SIZE) {
            return true
        }

        val playerBox = AABB(
            position.x - radius, position.y, position.z - radius,
            position.x + radius, position.y + height, position.z + radius
        )

        for (box in OBSTACLES) {
            if (box.intersects(playerBox)) {
                return true
            }
        }
        return false
    }

    /**
     * Raycast for bullet hits against obstacles.
     * Returns true if hits an obstacle, or false if clear.
     */
    fun raycastObstacle(from: Vec3, to: Vec3): Vec3? {
        val dir = to - from
        val dist = dir.length()
        if (dist <= 0.001f) return null
        val normDir = dir / dist
        val step = 0.3f
        var current = from
        var travelled = 0f

        while (travelled < dist) {
            current = current + normDir * step
            travelled += step

            // Boundary check
            if (current.x < -ARENA_HALF_SIZE || current.x > ARENA_HALF_SIZE ||
                current.z < -ARENA_HALF_SIZE || current.z > ARENA_HALF_SIZE ||
                current.y < 0f) {
                return current
            }

            for (box in OBSTACLES) {
                if (box.contains(current)) {
                    return current
                }
            }
        }
        return null
    }
}
