package com.example.game.engine

import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import com.example.game.arena.ArenaMap
import com.example.game.model.Bullet
import com.example.game.model.GamePalette
import com.example.game.model.RemotePlayer
import com.example.game.model.Vec3
import java.util.concurrent.CopyOnWriteArrayList
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.cos
import kotlin.math.sin

/**
 * 60 FPS hardware-accelerated OpenGL ES 2.0 Renderer.
 * Renders the multi-level arena (ground floor, mezzanine, stairs, barricades),
 * dynamic enemy players/bots, bullets, weapon models, and impact effects.
 */
class GameRenderer : GLSurfaceView.Renderer {

    // Matrices
    private val projectionMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)
    private val modelMatrix = FloatArray(16)
    private val mvpMatrix = FloatArray(16)
    private val normalMatrix = FloatArray(16)
    private val tempMatrix = FloatArray(16)

    // Shaders and Meshes
    private var programId = 0
    private var uMVPMatrixLoc = 0
    private var uModelMatrixLoc = 0
    private var uNormalMatrixLoc = 0
    private var uColorLoc = 0
    private var uLightDirLoc = 0
    private var uCameraPosLoc = 0
    private var aPositionLoc = 0
    private var aNormalLoc = 0

    private lateinit var cubeMesh: Mesh
    private lateinit var quadMesh: Mesh

    // Player Camera State
    @Volatile var playerPosition = Vec3(0f, 1f, 0f)
    @Volatile var cameraYaw = 0f
    @Volatile var cameraPitch = 0f
    @Volatile var muzzleFlashAlpha = 0f
    @Volatile var recoilProgress = 0f
    @Volatile var playerColorArgb = 0xFF3498DBL

    // Game Entities to render
    val enemyPlayers = CopyOnWriteArrayList<RemotePlayer>()
    val activeBullets = CopyOnWriteArrayList<Bullet>()

    // Viewport aspect
    private var aspectRatio = 1.777f

    // Shader sources with lighting, specular, and atmospheric distance fog
    private val vertexShaderCode = """
        uniform mat4 uMVPMatrix;
        uniform mat4 uModelMatrix;
        uniform mat4 uNormalMatrix;
        attribute vec4 aPosition;
        attribute vec3 aNormal;
        varying vec3 vNormal;
        varying vec3 vWorldPos;
        varying float vDistance;

        void main() {
            vec4 worldPos = uModelMatrix * aPosition;
            vWorldPos = worldPos.xyz;
            vNormal = normalize((uNormalMatrix * vec4(aNormal, 0.0)).xyz);
            vec4 clipPos = uMVPMatrix * aPosition;
            vDistance = clipPos.z;
            gl_Position = clipPos;
        }
    """.trimIndent()

    private val fragmentShaderCode = """
        precision mediump float;
        uniform vec4 uColor;
        uniform vec3 uLightDir;
        uniform vec3 uCameraPos;
        varying vec3 vNormal;
        varying vec3 vWorldPos;
        varying float vDistance;

        void main() {
            // Ambient + Diffuse Lighting
            vec3 norm = normalize(vNormal);
            float diff = max(dot(norm, uLightDir), 0.0);
            float ambient = 0.40;
            vec3 light = (ambient + diff * 0.60) * uColor.rgb;

            // Subtle Specular
            vec3 viewDir = normalize(uCameraPos - vWorldPos);
            vec3 reflectDir = reflect(-uLightDir, norm);
            float spec = pow(max(dot(viewDir, reflectDir), 0.0), 16.0);
            vec3 specular = vec3(0.25) * spec;

            vec3 finalColor = light + specular;

            // Distance fog fade into dark arena sky
            float fogFactor = clamp((vDistance - 25.0) / 45.0, 0.0, 0.85);
            vec3 fogColor = vec3(0.04, 0.07, 0.12);
            finalColor = mix(finalColor, fogColor, fogFactor);

            gl_FragColor = vec4(finalColor, uColor.a);
        }
    """.trimIndent()

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        // Deep sci-fi arena sky background
        GLES20.glClearColor(0.04f, 0.07f, 0.12f, 1.0f)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthFunc(GLES20.GL_LEQUAL)
        GLES20.glEnable(GLES20.GL_CULL_FACE)
        GLES20.glCullFace(GLES20.GL_BACK)

        programId = ShaderHelper.createProgram(vertexShaderCode, fragmentShaderCode)
        uMVPMatrixLoc = GLES20.glGetUniformLocation(programId, "uMVPMatrix")
        uModelMatrixLoc = GLES20.glGetUniformLocation(programId, "uModelMatrix")
        uNormalMatrixLoc = GLES20.glGetUniformLocation(programId, "uNormalMatrix")
        uColorLoc = GLES20.glGetUniformLocation(programId, "uColor")
        uLightDirLoc = GLES20.glGetUniformLocation(programId, "uLightDir")
        uCameraPosLoc = GLES20.glGetUniformLocation(programId, "uCameraPos")
        aPositionLoc = GLES20.glGetAttribLocation(programId, "aPosition")
        aNormalLoc = GLES20.glGetAttribLocation(programId, "aNormal")

        cubeMesh = MeshBuilder.createCube()
        quadMesh = MeshBuilder.createQuad()
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        aspectRatio = width.toFloat() / height.toFloat().coerceAtLeast(1f)
        Matrix.perspectiveM(projectionMatrix, 0, 68.0f, aspectRatio, 0.1f, 150.0f)
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        GLES20.glUseProgram(programId)

        // Set Light Direction and Camera Position
        val lightDir = floatArrayOf(0.45f, 0.85f, 0.25f)
        val lLen = kotlin.math.sqrt(lightDir[0] * lightDir[0] + lightDir[1] * lightDir[1] + lightDir[2] * lightDir[2])
        GLES20.glUniform3f(uLightDirLoc, lightDir[0] / lLen, lightDir[1] / lLen, lightDir[2] / lLen)

        val eyeY = playerPosition.y + 1.6f
        GLES20.glUniform3f(uCameraPosLoc, playerPosition.x, eyeY, playerPosition.z)

        // Calculate Camera Forward Vector from Yaw and Pitch
        val yawRad = Math.toRadians(cameraYaw.toDouble()).toFloat()
        val pitchRad = Math.toRadians(cameraPitch.toDouble()).toFloat()
        val forwardX = sin(yawRad) * cos(pitchRad)
        val forwardY = sin(pitchRad)
        val forwardZ = cos(yawRad) * cos(pitchRad)

        Matrix.setLookAtM(
            viewMatrix, 0,
            playerPosition.x, eyeY, playerPosition.z,
            playerPosition.x + forwardX, eyeY + forwardY, playerPosition.z + forwardZ,
            0f, 1f, 0f
        )

        // 1. Draw Checkerboard Ground Floor (from floor.py)
        drawGroundFloor()

        // 2. Draw Arena Architecture (Upper Deck slabs, pillars, railings, barricades)
        drawArenaBlocks()

        // 3. Draw Enemy Players and Bots
        drawPlayers()

        // 4. Draw Active Bullets
        drawBullets()

        // 5. Draw First-Person Weapon Model with Recoil & Muzzle Flash
        drawFirstPersonWeapon(forwardX, forwardY, forwardZ, yawRad, pitchRad)
    }

    private fun drawGroundFloor() {
        val dark1Color = floatArrayOf(0.18f, 0.22f, 0.28f, 1.0f)
        val dark2Color = floatArrayOf(0.12f, 0.15f, 0.20f, 1.0f)

        // 40x40 ground floor with 2x2 meter cubes
        for (z in -20 until 20 step 4) {
            val offset = ((z / 4) % 2 == 0)
            for (x in -20 until 20 step 4) {
                val isDark2 = if (offset) ((x / 4) % 2 == 0) else ((x / 4) % 2 != 0)
                val color = if (isDark2) dark2Color else dark1Color

                Matrix.setIdentityM(modelMatrix, 0)
                Matrix.translateM(modelMatrix, 0, x.toFloat() + 2f, 0.5f, z.toFloat() + 2f)
                Matrix.scaleM(modelMatrix, 0, 4f, 1f, 4f)
                drawMesh(cubeMesh, color)
            }
        }
    }

    private fun drawArenaBlocks() {
        for (block in ArenaMap.BLOCKS) {
            val colorFloats = GamePalette.colorToFloats(block.colorArgb)
            Matrix.setIdentityM(modelMatrix, 0)
            Matrix.translateM(modelMatrix, 0, block.center.x, block.center.y, block.center.z)
            Matrix.scaleM(modelMatrix, 0, block.size.x, block.size.y, block.size.z)
            drawMesh(cubeMesh, colorFloats)
        }
    }

    private fun drawPlayers() {
        for (player in enemyPlayers) {
            if (player.isDead) continue

            val baseColor = GamePalette.colorToFloats(player.colorArgb)
            val healthPercent = (player.health / player.maxHealth).coerceIn(0f, 1f)
            // Color saturation shift towards red when injured (from Ursina enemy.py)
            val redShift = 1.0f - healthPercent
            val renderColor = floatArrayOf(
                (baseColor[0] + redShift * 0.7f).coerceIn(0f, 1f),
                (baseColor[1] * (1f - redShift * 0.5f)).coerceIn(0f, 1f),
                (baseColor[2] * (1f - redShift * 0.5f)).coerceIn(0f, 1f),
                1.0f
            )

            // Player Body: scale (1, 2, 1) matching Ursina
            Matrix.setIdentityM(modelMatrix, 0)
            Matrix.translateM(modelMatrix, 0, player.position.x, player.position.y + 1.0f, player.position.z)
            Matrix.rotateM(modelMatrix, 0, player.rotationY, 0f, 1f, 0f)
            Matrix.scaleM(modelMatrix, 0, 1.0f, 2.0f, 1.0f)
            drawMesh(cubeMesh, renderColor)

            // Player Gun: scale (0.1, 0.2, 0.65) attached to right side (from enemy.py)
            Matrix.setIdentityM(modelMatrix, 0)
            Matrix.translateM(modelMatrix, 0, player.position.x, player.position.y + 1.0f, player.position.z)
            Matrix.rotateM(modelMatrix, 0, player.rotationY, 0f, 1f, 0f)
            Matrix.translateM(modelMatrix, 0, 0.55f, 0.5f, 0.6f)
            Matrix.scaleM(modelMatrix, 0, 0.12f, 0.2f, 0.65f)
            val gunColor = floatArrayOf(0.1f, 0.1f, 0.12f, 1.0f)
            drawMesh(cubeMesh, gunColor)

            // Overhead Health Bar
            Matrix.setIdentityM(modelMatrix, 0)
            Matrix.translateM(modelMatrix, 0, player.position.x, player.position.y + 2.4f, player.position.z)
            // Billboard to camera
            Matrix.rotateM(modelMatrix, 0, cameraYaw + 180f, 0f, 1f, 0f)
            Matrix.scaleM(modelMatrix, 0, 1.2f * healthPercent, 0.1f, 0.05f)
            val hpColor = if (healthPercent > 0.5f) floatArrayOf(0.1f, 0.9f, 0.2f, 1f) else floatArrayOf(0.9f, 0.2f, 0.1f, 1f)
            drawMesh(cubeMesh, hpColor)
        }
    }

    private fun drawBullets() {
        val bulletColor = floatArrayOf(1.0f, 0.85f, 0.15f, 1.0f)
        for (bullet in activeBullets) {
            if (bullet.isDestroyed) continue
            Matrix.setIdentityM(modelMatrix, 0)
            Matrix.translateM(modelMatrix, 0, bullet.position.x, bullet.position.y, bullet.position.z)
            Matrix.scaleM(modelMatrix, 0, 0.22f, 0.22f, 0.22f)
            drawMesh(cubeMesh, bulletColor)
        }
    }

    private fun drawFirstPersonWeapon(forwardX: Float, forwardY: Float, forwardZ: Float, yawRad: Float, pitchRad: Float) {
        // Clear depth so weapon doesn't clip into nearby walls
        GLES20.glClear(GLES20.GL_DEPTH_BUFFER_BIT)

        // Calculate right and up vectors
        val rightX = cos(yawRad)
        val rightZ = -sin(yawRad)

        val eyeY = playerPosition.y + 1.6f
        val recoilPunch = recoilProgress * 0.12f

        // Gun offset in view space: bottom-right
        val gunPosX = playerPosition.x + forwardX * (0.6f - recoilPunch) + rightX * 0.28f
        val gunPosY = eyeY + forwardY * (0.6f - recoilPunch) - 0.22f + recoilProgress * 0.04f
        val gunPosZ = playerPosition.z + forwardZ * (0.6f - recoilPunch) + rightZ * 0.28f

        Matrix.setIdentityM(modelMatrix, 0)
        Matrix.translateM(modelMatrix, 0, gunPosX, gunPosY, gunPosZ)
        Matrix.rotateM(modelMatrix, 0, cameraYaw, 0f, 1f, 0f)
        Matrix.rotateM(modelMatrix, 0, -cameraPitch - recoilProgress * 15f, 1f, 0f, 0f)

        // Gun Body: Dark metallic finish with player's custom accent color
        Matrix.scaleM(modelMatrix, 0, 0.12f, 0.18f, 0.55f)
        val weaponColor = GamePalette.colorToFloats(playerColorArgb)
        drawMesh(cubeMesh, weaponColor)

        // Muzzle Flash Effect when shooting
        if (muzzleFlashAlpha > 0.05f) {
            val flashColor = floatArrayOf(1.0f, 0.85f, 0.2f, muzzleFlashAlpha)
            Matrix.setIdentityM(modelMatrix, 0)
            val flashX = gunPosX + forwardX * 0.35f
            val flashY = gunPosY + forwardY * 0.35f
            val flashZ = gunPosZ + forwardZ * 0.35f
            Matrix.translateM(modelMatrix, 0, flashX, flashY, flashZ)
            Matrix.scaleM(modelMatrix, 0, 0.18f, 0.18f, 0.18f)
            drawMesh(cubeMesh, flashColor)
        }
    }

    private fun drawMesh(mesh: Mesh, color: FloatArray) {
        // Compute ModelViewProjection Matrix
        Matrix.multiplyMM(tempMatrix, 0, viewMatrix, 0, modelMatrix, 0)
        Matrix.multiplyMM(mvpMatrix, 0, projectionMatrix, 0, tempMatrix, 0)

        // Invert transpose model matrix for correct normals
        Matrix.invertM(tempMatrix, 0, modelMatrix, 0)
        Matrix.transposeM(normalMatrix, 0, tempMatrix, 0)

        GLES20.glUniformMatrix4fv(uMVPMatrixLoc, 1, false, mvpMatrix, 0)
        GLES20.glUniformMatrix4fv(uModelMatrixLoc, 1, false, modelMatrix, 0)
        GLES20.glUniformMatrix4fv(uNormalMatrixLoc, 1, false, normalMatrix, 0)
        GLES20.glUniform4fv(uColorLoc, 1, color, 0)

        mesh.vertexBuffer.position(0)
        GLES20.glVertexAttribPointer(aPositionLoc, 3, GLES20.GL_FLOAT, false, 0, mesh.vertexBuffer)
        GLES20.glEnableVertexAttribArray(aPositionLoc)

        mesh.normalBuffer.position(0)
        GLES20.glVertexAttribPointer(aNormalLoc, 3, GLES20.GL_FLOAT, false, 0, mesh.normalBuffer)
        GLES20.glEnableVertexAttribArray(aNormalLoc)

        mesh.indexBuffer.position(0)
        GLES20.glDrawElements(GLES20.GL_TRIANGLES, mesh.indexCount, GLES20.GL_UNSIGNED_SHORT, mesh.indexBuffer)

        GLES20.glDisableVertexAttribArray(aPositionLoc)
        GLES20.glDisableVertexAttribArray(aNormalLoc)
    }
}
