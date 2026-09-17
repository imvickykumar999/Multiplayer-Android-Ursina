# Ursina TCP Deathmatch

A small multiplayer first-person deathmatch game built with [Ursina](https://www.ursinaengine.org/) and Python TCP sockets. One player runs the server and other players connect as clients over a local network or a reachable public address.

![ss1](https://github.com/user-attachments/assets/7a095622-cace-4b6b-ab22-a85650ee0829)
![ss2](https://github.com/user-attachments/assets/5a8ee116-f210-4b19-b6e2-2d4e3109378e)
![ss3](https://github.com/user-attachments/assets/fc62d38a-21d0-4b61-9d94-5be7ecd3db34)
![ss4](https://github.com/user-attachments/assets/bbc3a59b-2cb8-4d2e-b88a-5fc56c5e0c7d)

## Features

- First-person movement, jumping, shooting, health, death, and respawning
- Up to 10 concurrent players
- Player names represented by selectable colors
- TCP networking for player movement, health, bullets, and respawn events
- Fullscreen Ursina game window with a Tkinter connection screen

## 🚀 Quick Start: Play with Standalone Executables (No Python Required)

Pre-built Windows executables are provided in the [`play/`](play/) folder:

| Role | Executable Path | Description |
| --- | --- | --- |
| **Server (Host)** | [`play/server.exe`](play/server.exe) | Hosts the game session, manages player states and bullet physics. |
| **Client (Player)** | [`play/client.exe`](play/client.exe) | Opens the connection GUI, selects player color/username, and launches the 3D game. |

---

## 🌐 Multiplayer Guide: Playing Over Tailscale (Recommended)

Tailscale creates a secure, encrypted peer-to-peer mesh VPN between your devices. It allows players from **different homes, networks, or Wi-Fi connections** to play together directly without port forwarding, router configuration, or Hamachi.

### Step 1: Install & Set Up Tailscale

1. **Download Tailscale:**
   - Download the installer for Windows, macOS, Linux, Android, or iOS from the official site:  
     👉 **[https://tailscale.com/download](https://tailscale.com/download)**
2. **Sign In:**
   - Launch Tailscale and sign in (using Google, GitHub, Microsoft, or Apple account).
3. **Connect Your Devices:**
   - **Method A (Same Account):** Sign into the same Tailscale account on all player devices.
   - **Method B (Node Sharing):** The host signs into their Tailscale admin console, clicks the `...` menu next to their machine, selects **Share...**, and sends the invite link to the players.
4. **Find Your Tailscale IP:**
   - The host's Tailscale IPv4 address starts with `100.x.y.z` (for example, `100.121.132.98`).
   - You can view it by clicking the Tailscale tray icon, running `tailscale ip -4` in PowerShell, or looking at the server console.

### Step 2: Host Starts the Server (`server.exe`)

1. Double-click [`play/server.exe`](play/server.exe) (or run `python server/main.py`).
2. A terminal window will open and automatically detect your Tailscale IP:
   ```text
   ==================================================
   [*] Server started, listening on 0.0.0.0:8888...
   [*] Tailscale IP  = 100.121.132.98 (Use this for Tailscale)
   [*] Local LAN IP  = 192.168.x.x / 10.x.x.x (Same Wi-Fi only)
   ==================================================
   ```
3. Share the displayed **Tailscale IP** (e.g. `100.121.132.98`) with your friends. Keep this window open.

### Step 3: Players Launch the Client (`client.exe`)

1. Each player double-clicks [`play/client.exe`](play/client.exe) (or runs `python client/main.py`).
2. On the connection screen:
   - **Username:** Select your favorite color or enter a custom username.
   - **Server Address:** Enter the host's **Tailscale IP** (e.g. `100.121.132.98`).
     - *Note:* If running the client on the host machine itself, the Tailscale IP is auto-detected and pre-filled in the dropdown!
   - **Port:** Keep default `8888`.
3. Click **Play** (or press `Enter`). The game will connect and launch into fullscreen 3D!

---

## 📶 Alternative: Playing on the Same Local Wi-Fi (LAN)

If all computers are connected to the exact same home/office Wi-Fi router:

1. Host launches [`play/server.exe`](play/server.exe) and notes the **Local LAN IP** (e.g. `192.168.0.x` or `10.x.x.x`).
2. Other players on that same Wi-Fi launch [`play/client.exe`](play/client.exe), enter that Local LAN IP, and click **Play**.
3. Ensure Windows Firewall allows Python/server inbound traffic if prompted.

---

## 💻 Playing on a Single PC (Testing / Solo)

1. Run [`play/server.exe`](play/server.exe).
2. Run [`play/client.exe`](play/client.exe).
3. Use `127.0.0.1` or your Tailscale IP as the server address, port `8888`, and click **Play**.

---

## 🛠️ Running From Source (Python)

If you prefer running or modifying the Python source code directly:

### Requirements
- Python 3.10 or newer
- Windows, Linux, or macOS

### Setup Virtual Environment
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```
*(On Linux/macOS: `source .venv/bin/activate`)*

### Start Server & Client
```powershell
# Terminal 1: Server
python server/main.py

# Terminal 2: Client
python client/main.py
```

## Controls

| Action | Control |
| --- | --- |
| Move | `W` `A` `S` `D` |
| Jump | `Space` |
| Aim | Mouse |
| Shoot | Left mouse button |
| Respawn after death | `R`, `Space`, `Enter`, or the respawn button |
| Exit | `Esc` |

## Network Setup

- **Tailscale (Recommended):** No router changes, static IPs, or port forwarding required. Traffic travels encrypted over your Tailnet. To verify communication between devices, run:
  ```powershell
  tailscale ping <host-tailscale-ip>
  ```
- **Local Wi-Fi / LAN:** Make sure all devices are connected to the same router and Windows Firewall allows inbound TCP traffic on port `8888`.
- **Public Internet (Direct):** If not using Tailscale or VPNs, forward TCP port `8888` on the router to the host machine or use a TCP tunneling service (such as [playit.gg](https://playit.gg)).

## Project Layout

```text
play/
	server.exe    Standalone server executable
	client.exe    Standalone client executable
client/
	main.py       Client entry point and game loop
	network.py    TCP client and message serialization
	player.py     Local player, health, death, and respawn behavior
	enemy.py      Remote player representation
	bullet.py     Projectile behavior
	floor.py      Arena floor
	map.py        Arena geometry
	assets/       Textures and audio
server/
	main.py       TCP game server
requirements.txt
```

## Troubleshooting

- **Tailscale connection issue:** Ensure Tailscale is running on both host and client machines (icon should be active). Run `tailscale status` to confirm both devices appear on the network, and `tailscale ping <host-tailscale-ip>` to verify connectivity.
- **Connection refused:** Confirm the host has already started `server.exe` and is listening on port `8888`.
- **Timeout:** Check that Windows Firewall isn't blocking `server.exe` or `python.exe`. When Windows prompts you on first run, click **Allow access**.
- **Invalid address:** Ensure the client entered a valid IPv4 address (e.g. `100.x.y.z` for Tailscale or `192.168.x.x` for local Wi-Fi).
- **Port already in use:** If port `8888` is already bound by an existing server instance, close the previous `server.exe` window or terminate the background process.

## License

See [LICENSE](LICENSE).
