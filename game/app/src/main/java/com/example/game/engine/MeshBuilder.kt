package com.example.game.engine

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer

class Mesh(
    val vertexBuffer: FloatBuffer,
    val normalBuffer: FloatBuffer,
    val indexBuffer: ShortBuffer,
    val indexCount: Int
)

object MeshBuilder {

    fun createCube(): Mesh {
        // 24 vertices for a 1x1x1 cube with separate normals per face for flat lighting
        val vertices = floatArrayOf(
            // Front face (Z = 0.5)
            -0.5f, -0.5f,  0.5f,
             0.5f, -0.5f,  0.5f,
             0.5f,  0.5f,  0.5f,
            -0.5f,  0.5f,  0.5f,
            // Back face (Z = -0.5)
            -0.5f, -0.5f, -0.5f,
            -0.5f,  0.5f, -0.5f,
             0.5f,  0.5f, -0.5f,
             0.5f, -0.5f, -0.5f,
            // Top face (Y = 0.5)
            -0.5f,  0.5f, -0.5f,
            -0.5f,  0.5f,  0.5f,
             0.5f,  0.5f,  0.5f,
             0.5f,  0.5f, -0.5f,
            // Bottom face (Y = -0.5)
            -0.5f, -0.5f, -0.5f,
             0.5f, -0.5f, -0.5f,
             0.5f, -0.5f,  0.5f,
            -0.5f, -0.5f,  0.5f,
            // Right face (X = 0.5)
             0.5f, -0.5f, -0.5f,
             0.5f,  0.5f, -0.5f,
             0.5f,  0.5f,  0.5f,
             0.5f, -0.5f,  0.5f,
            // Left face (X = -0.5)
            -0.5f, -0.5f, -0.5f,
            -0.5f, -0.5f,  0.5f,
            -0.5f,  0.5f,  0.5f,
            -0.5f,  0.5f, -0.5f
        )

        val normals = floatArrayOf(
            // Front
             0f,  0f,  1f,   0f,  0f,  1f,   0f,  0f,  1f,   0f,  0f,  1f,
            // Back
             0f,  0f, -1f,   0f,  0f, -1f,   0f,  0f, -1f,   0f,  0f, -1f,
            // Top
             0f,  1f,  0f,   0f,  1f,  0f,   0f,  1f,  0f,   0f,  1f,  0f,
            // Bottom
             0f, -1f,  0f,   0f, -1f,  0f,   0f, -1f,  0f,   0f, -1f,  0f,
            // Right
             1f,  0f,  0f,   1f,  0f,  0f,   1f,  0f,  0f,   1f,  0f,  0f,
            // Left
            -1f,  0f,  0f,  -1f,  0f,  0f,  -1f,  0f,  0f,  -1f,  0f,  0f
        )

        val indices = shortArrayOf(
             0,  1,  2,      0,  2,  3,    // Front
             4,  5,  6,      4,  6,  7,    // Back
             8,  9, 10,      8, 10, 11,    // Top
            12, 13, 14,     12, 14, 15,    // Bottom
            16, 17, 18,     16, 18, 19,    // Right
            20, 21, 22,     20, 22, 23     // Left
        )

        val vBuf = ByteBuffer.allocateDirect(vertices.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer().put(vertices)
        vBuf.position(0)

        val nBuf = ByteBuffer.allocateDirect(normals.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer().put(normals)
        nBuf.position(0)

        val iBuf = ByteBuffer.allocateDirect(indices.size * 2)
            .order(ByteOrder.nativeOrder()).asShortBuffer().put(indices)
        iBuf.position(0)

        return Mesh(vBuf, nBuf, iBuf, indices.size)
    }

    fun createQuad(): Mesh {
        val vertices = floatArrayOf(
            -1f, -1f, 0f,
             1f, -1f, 0f,
             1f,  1f, 0f,
            -1f,  1f, 0f
        )
        val normals = floatArrayOf(
            0f, 0f, 1f,
            0f, 0f, 1f,
            0f, 0f, 1f,
            0f, 0f, 1f
        )
        val indices = shortArrayOf(0, 1, 2, 0, 2, 3)

        val vBuf = ByteBuffer.allocateDirect(vertices.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer().put(vertices)
        vBuf.position(0)

        val nBuf = ByteBuffer.allocateDirect(normals.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer().put(normals)
        nBuf.position(0)

        val iBuf = ByteBuffer.allocateDirect(indices.size * 2)
            .order(ByteOrder.nativeOrder()).asShortBuffer().put(indices)
        iBuf.position(0)

        return Mesh(vBuf, nBuf, iBuf, indices.size)
    }
}
