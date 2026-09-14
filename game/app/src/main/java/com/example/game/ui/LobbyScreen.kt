package com.example.game.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.model.GamePalette
import com.example.game.viewmodel.GameScreenState
import com.example.game.viewmodel.GameUiState

/**
 * Lobby & Match Setup screen matching the Python Tkinter interface:
 * Select username & player color, configure server IP & port,
 * and choose between Online TCP Match or Offline Bot Practice.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LobbyScreen(
    uiState: GameUiState,
    onUsernameChange: (String) -> Unit,
    onServerHostChange: (String) -> Unit,
    onServerPortChange: (Int) -> Unit,
    onStartOnline: () -> Unit,
    onStartPractice: () -> Unit
) {
    var showInfoDialog by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(Color(0xFF040812), Color(0xFF0B1325), Color(0xFF070B16))
                )
            )
            .testTag("lobby_screen"),
        contentAlignment = Alignment.Center
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth(0.92f)
                .padding(vertical = 12.dp)
                .shadow(16.dp, RoundedCornerShape(20.dp)),
            colors = CardDefaults.cardColors(containerColor = Color(0xEE0B1326)),
            shape = RoundedCornerShape(20.dp),
            border = CardDefaults.outlinedCardBorder().copy(
                brush = Brush.linearGradient(
                    listOf(Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF1E293B))
                )
            )
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 18.dp)
                    .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Game Title & Tagline
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "DEATHMATCH 3D",
                            color = Color(0xFF38BDF8),
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Black,
                            letterSpacing = 2.sp
                        )
                        Text(
                            text = "TCP Multiplayer & Mezzanine Arena",
                            color = Color(0xFF94A3B8),
                            fontSize = 12.sp
                        )
                    }

                    OutlinedButton(
                        onClick = { showInfoDialog = true },
                        modifier = Modifier.testTag("arena_info_button"),
                        shape = RoundedCornerShape(8.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFF38BDF8))
                    ) {
                        Icon(Icons.Default.Info, contentDescription = "Info", modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Arena Guide", fontSize = 12.sp)
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                // 1. Username & Color Selection
                Column(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "PLAYER USERNAME & COLOR",
                            color = Color(0xFFE2E8F0),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(12.dp)
                                    .clip(CircleShape)
                                    .background(Color(uiState.playerColorArgb))
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = "Color Tag",
                                color = Color(uiState.playerColorArgb),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(6.dp))

                    OutlinedTextField(
                        value = uiState.username,
                        onValueChange = onUsernameChange,
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("username_input"),
                        singleLine = true,
                        shape = RoundedCornerShape(10.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = Color.White,
                            unfocusedTextColor = Color.White,
                            focusedBorderColor = Color(0xFF38BDF8),
                            unfocusedBorderColor = Color(0xFF334155),
                            focusedContainerColor = Color(0x660F172A),
                            unfocusedContainerColor = Color(0x660F172A)
                        ),
                        placeholder = { Text("Enter username...", color = Color.Gray) }
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Palette Quick Select Chips
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        for (cname in GamePalette.COLOR_NAMES) {
                            val colorVal = GamePalette.COLOR_PALETTE[cname] ?: 0xFFFFFFFF
                            val isSelected = uiState.username.equals(cname, ignoreCase = true)
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(if (isSelected) Color(colorVal).copy(alpha = 0.35f) else Color(0x331E293B))
                                    .border(
                                        1.5.dp,
                                        if (isSelected) Color(colorVal) else Color(0x33475569),
                                        RoundedCornerShape(16.dp)
                                    )
                                    .clickable { onUsernameChange(cname) }
                                    .padding(horizontal = 10.dp, vertical = 5.dp)
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(
                                        modifier = Modifier
                                            .size(8.dp)
                                            .clip(CircleShape)
                                            .background(Color(colorVal))
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        text = cname,
                                        color = if (isSelected) Color.White else Color(0xFFCBD5E1),
                                        fontSize = 11.sp,
                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                // 2. Server Configuration
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = "SERVER ADDRESS & PORT",
                        color = Color(0xFFE2E8F0),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )

                    Spacer(modifier = Modifier.height(6.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        OutlinedTextField(
                            value = uiState.serverHost,
                            onValueChange = onServerHostChange,
                            modifier = Modifier
                                .weight(0.72f)
                                .testTag("server_host_input"),
                            label = { Text("Server Host IP", color = Color(0xFF94A3B8), fontSize = 11.sp) },
                            singleLine = true,
                            shape = RoundedCornerShape(10.dp),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedTextColor = Color.White,
                                unfocusedTextColor = Color.White,
                                focusedBorderColor = Color(0xFF38BDF8),
                                unfocusedBorderColor = Color(0xFF334155),
                                focusedContainerColor = Color(0x660F172A),
                                unfocusedContainerColor = Color(0x660F172A)
                            )
                        )

                        OutlinedTextField(
                            value = uiState.serverPort.toString(),
                            onValueChange = { str ->
                                str.toIntOrNull()?.let { onServerPortChange(it) }
                            },
                            modifier = Modifier
                                .weight(0.28f)
                                .testTag("server_port_input"),
                            label = { Text("Port", color = Color(0xFF94A3B8), fontSize = 11.sp) },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            shape = RoundedCornerShape(10.dp),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedTextColor = Color.White,
                                unfocusedTextColor = Color.White,
                                focusedBorderColor = Color(0xFF38BDF8),
                                unfocusedBorderColor = Color(0xFF334155),
                                focusedContainerColor = Color(0x660F172A),
                                unfocusedContainerColor = Color(0x660F172A)
                            )
                        )
                    }

                    Spacer(modifier = Modifier.height(6.dp))

                    // Host presets
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        listOf("127.0.0.1", "10.0.2.2").forEach { ip ->
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(6.dp))
                                    .background(Color(0x331E293B))
                                    .border(1.dp, Color(0x44475569), RoundedCornerShape(6.dp))
                                    .clickable { onServerHostChange(ip) }
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                            ) {
                                Text(
                                    text = if (ip == "10.0.2.2") "10.0.2.2 (Emulator Host)" else "$ip (Localhost)",
                                    color = Color(0xFF38BDF8),
                                    fontSize = 10.sp
                                )
                            }
                        }
                    }
                }

                if (uiState.connectionStatusText.isNotBlank()) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = uiState.connectionStatusText,
                        color = if (uiState.connectionStatusText.startsWith("Error")) Color(0xFFEF4444) else Color(0xFF38BDF8),
                        fontSize = 12.sp
                    )
                }

                Spacer(modifier = Modifier.height(18.dp))

                // 3. Action Buttons
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    // Practice Mode Button
                    Button(
                        onClick = onStartPractice,
                        modifier = Modifier
                            .weight(1f)
                            .height(52.dp)
                            .testTag("practice_button"),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1E293B)),
                        shape = RoundedCornerShape(12.dp),
                        border = ButtonDefaults.outlinedButtonBorder.copy(
                            brush = Brush.linearGradient(listOf(Color(0xFF38BDF8), Color(0xFF0284C7)))
                        )
                    ) {
                        Icon(Icons.Default.SmartToy, contentDescription = null, tint = Color(0xFF38BDF8))
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text("PRACTICE", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            Text("VS 4 AI BOTS", color = Color(0xFF94A3B8), fontSize = 10.sp)
                        }
                    }

                    // Online TCP Connect Button
                    Button(
                        onClick = onStartOnline,
                        modifier = Modifier
                            .weight(1f)
                            .height(52.dp)
                            .testTag("connect_online_button"),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0284C7)),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        if (uiState.screenState == GameScreenState.CONNECTING) {
                            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("CONNECTING...", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        } else {
                            Icon(Icons.Default.Wifi, contentDescription = null, tint = Color.White)
                            Spacer(modifier = Modifier.width(8.dp))
                            Column {
                                Text("JOIN ONLINE", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                Text("TCP SERVER :${uiState.serverPort}", color = Color(0xFFBAE6FD), fontSize = 10.sp)
                            }
                        }
                    }
                }
            }
        }

        // Info Guide Dialog
        if (showInfoDialog) {
            AlertDialog(
                onDismissRequest = { showInfoDialog = false },
                title = {
                    Text(
                        "Deathmatch 3D Arena Guide",
                        color = Color(0xFF38BDF8),
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp
                    )
                },
                text = {
                    Column(
                        modifier = Modifier.verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            "• 40x40 Combat Arena: Two levels of intense combat. Ground floor arena with center barricades and tactical corner bunkers.",
                            color = Color.LightGray,
                            fontSize = 13.sp
                        )
                        Text(
                            "• Mezzanine Upper Deck: Elevated 1st floor platform at y=6.0 with open atrium overlook.",
                            color = Color.LightGray,
                            fontSize = 13.sp
                        )
                        Text(
                            "• Dual Staircases: East & West stairs with smooth ramps to flank enemies between floors.",
                            color = Color.LightGray,
                            fontSize = 13.sp
                        )
                        Text(
                            "• Weapons & HP: 250 HP max. Bullets deal 8-22 damage with bullet drop and recoil. 5-second respawn timer upon elimination.",
                            color = Color.LightGray,
                            fontSize = 13.sp
                        )
                        Text(
                            "• TCP Protocol: Fully compatible with Python Ursina server on port 8888. Supports LAN, Tailscale mesh VPN, or built-in offline bot deathmatch.",
                            color = Color.LightGray,
                            fontSize = 13.sp
                        )
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showInfoDialog = false }) {
                        Text("GOT IT", color = Color(0xFF38BDF8), fontWeight = FontWeight.Bold)
                    }
                },
                containerColor = Color(0xFF0F172A),
                shape = RoundedCornerShape(16.dp)
            )
        }
    }
}
