# Deathmatch Server

This directory contains the TCP server for Ursina-TCP-Deathmatch. The server listens on `0.0.0.0:8888` and accepts up to 10 players.

**Windows EXE output:**

![Windows EXE Output](https://github.com/user-attachments/assets/99962b82-4e9d-40a5-b900-5f88a7eb6bae)

---

**Ubuntu Executable:**

![Ubuntu Output](https://github.com/user-attachments/assets/9e781451-001b-4e54-877b-39038873a553)

---

## Run From Python

Open PowerShell or a terminal in this directory:

```powershell
cd server
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install art
python main.py
```

On Windows Command Prompt, activate the environment with:

```bat
.venv\Scripts\activate.bat
```

The server prints its Tailscale IPv4 address (if active) and local IPv4 address when it starts. Press `Ctrl+C` to stop it.

## Network Setup

Clients must connect to the server machine's IPv4 address on port `8888`.

- **Via Tailscale (Recommended for remote play):** Install Tailscale from [https://tailscale.com/download](https://tailscale.com/download) on host and client devices. Clients connect using the host's Tailscale IPv4 address (e.g. `100.x.y.z`). No port forwarding or router changes required!
- **Local Network (LAN):** For computers on the same network, clients connect to the server machine's local LAN IP. Allow inbound TCP traffic on port `8888` in the server machine's firewall.
- **Port Forwarding / Tunnels:** For direct internet access without a mesh VPN, forward TCP port `8888` on your router or use an external TCP tunnel. The port is defined by `PORT` in `main.py` and must match the client configuration.

## Build `server.exe` on Windows

Install PyInstaller in the active environment:

```powershell
python -m pip install pyinstaller
```

Build using the checked-in spec file:

```powershell
pyinstaller --clean --noconfirm server.spec
```

The executable is created at:

```text
server\dist\server.exe
```

Run the built server from the `server` directory:

```powershell
.\dist\server.exe
```

The spec file includes the `art` and `json` imports and uses `icon.ico`. If a previous build is causing problems, remove the generated folders and rebuild:

```powershell
Remove-Item -Recurse -Force build, dist
pyinstaller --clean --noconfirm server.spec
```

## Build on Linux

PyInstaller creates executables for the operating system where it runs. Build separately on Linux rather than copying the Windows `.exe`:

```bash
cd server
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install art pyinstaller
pyinstaller --clean --noconfirm server.spec
chmod +x dist/server
./dist/server
```

The Linux executable is `dist/server`. Keep the server process running while clients connect, and make sure TCP port `8888` is open in the host firewall.

## Changing the Port

Edit `PORT` in `main.py`, then rebuild the executable if you are using `server.exe`. Clients must use the same port.
