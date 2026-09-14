package com.example.game.network

import android.util.Log
import com.example.game.model.Bullet
import com.example.game.model.Vec3
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.LinkedBlockingQueue

sealed class ConnectionState {
    object Disconnected : ConnectionState()
    object Connecting : ConnectionState()
    data class Connected(val assignedId: String, val serverHost: String, val serverPort: Int) : ConnectionState()
    data class Error(val message: String) : ConnectionState()
}

sealed class NetworkMessage {
    data class PlayerUpdate(
        val id: String,
        val username: String?,
        val position: Vec3,
        val rotationY: Float,
        val health: Float,
        val joined: Boolean,
        val left: Boolean
    ) : NetworkMessage()

    data class PlayerRespawn(
        val id: String,
        val position: Vec3,
        val health: Float
    ) : NetworkMessage()

    data class BulletSpawn(
        val position: Vec3,
        val directionY: Float,
        val directionX: Float,
        val damage: Int
    ) : NetworkMessage()

    data class HealthUpdate(
        val id: String,
        val health: Float
    ) : NetworkMessage()
}

/**
 * High-performance TCP client matching Python network.py protocol:
 * - Handshake: receives ID, sends username
 * - Streams JSON packet fragments/objects
 * - Background worker thread for non-blocking socket writes
 */
class GameNetworkClient(
    private val scope: CoroutineScope
) {
    private val TAG = "GameNetworkClient"

    private var socket: Socket? = null
    private var inputStream: InputStream? = null
    private var outputStream: OutputStream? = null

    private val outgoingQueue = LinkedBlockingQueue<String>()
    private var networkJob: Job? = null
    private var sendJob: Job? = null

    private val _connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    private val _incomingMessages = MutableSharedFlow<NetworkMessage>(extraBufferCapacity = 64)
    val incomingMessages: SharedFlow<NetworkMessage> = _incomingMessages.asSharedFlow()

    var myId: String = ""
        private set
    var currentUsername: String = ""
        private set

    fun connect(host: String, port: Int, username: String) {
        if (_connectionState.value is ConnectionState.Connecting || _connectionState.value is ConnectionState.Connected) {
            disconnect()
        }

        currentUsername = username
        _connectionState.value = ConnectionState.Connecting

        networkJob = scope.launch(Dispatchers.IO) {
            try {
                Log.d(TAG, "Connecting to $host:$port...")
                val sock = Socket()
                sock.tcpNoDelay = true
                sock.soTimeout = 0 // non-blocking / infinite timeout for streaming
                sock.connect(InetSocketAddress(host, port), 6000)

                socket = sock
                val input = sock.getInputStream()
                val output = sock.getOutputStream()
                inputStream = input
                outputStream = output

                // Read assigned ID
                val buffer = ByteArray(2048)
                val readCount = input.read(buffer)
                if (readCount <= 0) {
                    throw Exception("Failed to receive ID from server")
                }
                val idRaw = String(buffer, 0, readCount, Charsets.UTF_8).trim()
                myId = if (idRaw.contains("\n")) idRaw.substringBefore("\n").trim() else idRaw
                Log.d(TAG, "Assigned Player ID: $myId")

                // Send username
                val userPayload = "$username\n".toByteArray(Charsets.UTF_8)
                output.write(userPayload)
                output.flush()

                _connectionState.value = ConnectionState.Connected(myId, host, port)

                // Start sender loop
                startSendLoop()

                // Stream receive loop
                val sb = StringBuilder()
                val readBuf = ByteArray(4096)

                while (isActive && !sock.isClosed) {
                    val count = input.read(readBuf)
                    if (count <= 0) break
                    sb.append(String(readBuf, 0, count, Charsets.UTF_8))

                    // Parse JSON objects {...}
                    while (true) {
                        val startIdx = sb.indexOf('{')
                        if (startIdx == -1) {
                            sb.clear()
                            break
                        }
                        var depth = 0
                        var endIdx = -1
                        for (i in startIdx until sb.length) {
                            if (sb[i] == '{') depth++
                            else if (sb[i] == '}') {
                                depth--
                                if (depth == 0) {
                                    endIdx = i
                                    break
                                }
                            }
                        }

                        if (endIdx != -1) {
                            val jsonStr = sb.substring(startIdx, endIdx + 1)
                            sb.delete(0, endIdx + 1)
                            try {
                                parseAndDispatch(jsonStr)
                            } catch (e: Exception) {
                                Log.w(TAG, "Error parsing JSON packet: ${e.message}")
                            }
                        } else {
                            // Incomplete JSON object, wait for more data
                            if (startIdx > 0) {
                                sb.delete(0, startIdx)
                            }
                            break
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Connection failed: ${e.message}")
                if (isActive) {
                    _connectionState.value = ConnectionState.Error(e.message ?: "Connection failed")
                }
            } finally {
                disconnect()
            }
        }
    }

    private fun startSendLoop() {
        sendJob = scope.launch(Dispatchers.IO) {
            val out = outputStream ?: return@launch
            while (isActive) {
                try {
                    val msg = outgoingQueue.take()
                    val bytes = (msg + "\n").toByteArray(Charsets.UTF_8)
                    out.write(bytes)
                    out.flush()
                } catch (e: InterruptedException) {
                    break
                } catch (e: Exception) {
                    Log.w(TAG, "Socket send error: ${e.message}")
                    break
                }
            }
        }
    }

    private fun parseAndDispatch(jsonStr: String) {
        val json = JSONObject(jsonStr)
        val objType = json.optString("object")
        val senderId = json.optString("id")

        when (objType) {
            "player" -> {
                val posArray = json.optJSONArray("position")
                val pos = if (posArray != null && posArray.length() >= 3) {
                    Vec3(
                        posArray.optDouble(0).toFloat(),
                        posArray.optDouble(1).toFloat(),
                        posArray.optDouble(2).toFloat()
                    )
                } else Vec3(0f, 1f, 0f)

                val rotY = json.optDouble("rotation", 0.0).toFloat()
                val health = json.optDouble("health", 250.0).toFloat()
                val joined = json.optBoolean("joined", false)
                val left = json.optBoolean("left", false)
                val username = json.optString("username", null)

                _incomingMessages.tryEmit(
                    NetworkMessage.PlayerUpdate(
                        id = senderId,
                        username = username,
                        position = pos,
                        rotationY = rotY,
                        health = health,
                        joined = joined,
                        left = left
                    )
                )
            }

            "player_respawn", "respawn" -> {
                val posArray = json.optJSONArray("position")
                val pos = if (posArray != null && posArray.length() >= 3) {
                    Vec3(
                        posArray.optDouble(0).toFloat(),
                        posArray.optDouble(1).toFloat(),
                        posArray.optDouble(2).toFloat()
                    )
                } else Vec3(0f, 1f, 0f)
                val health = json.optDouble("health", 250.0).toFloat()
                _incomingMessages.tryEmit(NetworkMessage.PlayerRespawn(senderId, pos, health))
            }

            "bullet" -> {
                val posArray = json.optJSONArray("position")
                val pos = if (posArray != null && posArray.length() >= 3) {
                    Vec3(
                        posArray.optDouble(0).toFloat(),
                        posArray.optDouble(1).toFloat(),
                        posArray.optDouble(2).toFloat()
                    )
                } else Vec3(0f, 1f, 0f)
                val dirY = json.optDouble("direction", 0.0).toFloat()
                val dirX = json.optDouble("x_direction", 0.0).toFloat()
                val damage = json.optInt("damage", 15)
                _incomingMessages.tryEmit(NetworkMessage.BulletSpawn(pos, dirY, dirX, damage))
            }

            "health_update" -> {
                val health = json.optDouble("health", 250.0).toFloat()
                _incomingMessages.tryEmit(NetworkMessage.HealthUpdate(senderId, health))
            }
        }
    }

    fun sendPlayer(pos: Vec3, rotationY: Float, health: Float) {
        if (_connectionState.value !is ConnectionState.Connected) return
        val json = JSONObject()
        json.put("object", "player")
        json.put("id", myId)
        val posArray = JSONArray()
        posArray.put(pos.x.toDouble())
        posArray.put(pos.y.toDouble())
        posArray.put(pos.z.toDouble())
        json.put("position", posArray)
        json.put("rotation", rotationY.toDouble())
        json.put("health", health.toDouble())
        json.put("joined", false)
        json.put("left", false)
        outgoingQueue.offer(json.toString())
    }

    fun sendBullet(bullet: Bullet) {
        if (_connectionState.value !is ConnectionState.Connected) return
        val json = JSONObject()
        json.put("object", "bullet")
        val posArray = JSONArray()
        posArray.put(bullet.position.x.toDouble())
        posArray.put(bullet.position.y.toDouble())
        posArray.put(bullet.position.z.toDouble())
        json.put("position", posArray)
        json.put("damage", bullet.damage)
        json.put("direction", bullet.directionY.toDouble())
        json.put("x_direction", bullet.directionX.toDouble())
        outgoingQueue.offer(json.toString())
    }

    fun sendHealthUpdate(targetId: String, newHealth: Float) {
        if (_connectionState.value !is ConnectionState.Connected) return
        val json = JSONObject()
        json.put("object", "health_update")
        json.put("id", targetId)
        json.put("health", newHealth.toDouble())
        outgoingQueue.offer(json.toString())
    }

    fun sendRespawn(pos: Vec3, health: Float = 250f) {
        if (_connectionState.value !is ConnectionState.Connected) return
        val json = JSONObject()
        json.put("object", "respawn")
        json.put("id", myId)
        val posArray = JSONArray()
        posArray.put(pos.x.toDouble())
        posArray.put(pos.y.toDouble())
        posArray.put(pos.z.toDouble())
        json.put("position", posArray)
        json.put("health", health.toDouble())
        outgoingQueue.offer(json.toString())
    }

    fun disconnect() {
        try {
            outgoingQueue.clear()
            socket?.close()
        } catch (_: Exception) {
        }
        socket = null
        inputStream = null
        outputStream = null
        sendJob?.cancel()
        networkJob?.cancel()
        if (_connectionState.value !is ConnectionState.Disconnected) {
            _connectionState.value = ConnectionState.Disconnected
        }
    }
}
