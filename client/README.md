# 🐳 How to Dockerize a GUI-based Ursina Game Client

**Docker Image: [imvickykumar999/ursina-client](https://hub.docker.com/r/imvickykumar999/ursina-client)**

![WhatsApp Image 2025-06-01 at 12 20 11_12e2a83a](https://github.com/user-attachments/assets/92f62308-d848-468c-a56c-e10e9e079fe1)
![image](https://github.com/user-attachments/assets/a09c1895-5d4a-49d8-b327-ec985fa8ad5d)

## Ursina Deathmatch Client

This is the Docker client for Ursina TCP Deathmatch. It opens the game window and connects to a running deathmatch server.

## Before You Start

You need:

- Docker Desktop or Docker Engine
- A running game server
- A graphical desktop session
- The server IPv4 address and TCP port

The default server port is `8888`. Start the server from the repository's `server` folder before launching the client:

```bash
python main.py
```

The server host should share its displayed IPv4 address with the players. Players on the same computer can use `127.0.0.1`; players on the same LAN should use the server computer's local IPv4 address.

## Pull the Image

Pull the published image from Docker Hub:

```bash
docker pull imvickykumar999/ursina-client:latest
```

## Play on Linux

The client uses X11 to display its Ursina and Tkinter windows. Allow the Docker container to use the local X server, then run the image:

```bash
xhost +local:docker

docker run --rm -it \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  imvickykumar999/ursina-client:latest
```

The connection screen opens inside the container. Enter your username, the server address, and port `8888`, then select **Play**.

When finished, optionally restore the X server access rule:

```bash
xhost -local:docker
```

## Play on Windows

Docker Desktop containers need an X server to show a Linux GUI. Install and start [VcXsrv](https://sourceforge.net/projects/vcxsrv/) or X410, then configure it to accept connections.

In PowerShell, set the display address and run the image:

```powershell
$env:DISPLAY = "host.docker.internal:0.0"

docker run --rm -it `
  -e DISPLAY=$env:DISPLAY `
  imvickykumar999/ursina-client:latest
```

If the game window does not appear, check that the X server is running, that its access control allows Docker Desktop, and that Windows Firewall is not blocking it. Using the client directly with Python is usually simpler on Windows when Docker GUI forwarding is unavailable:

```powershell
python main.py
```

## Controls

| Action | Control |
| --- | --- |
| Move | `W` `A` `S` `D` |
| Jump | `Space` |
| Aim | Mouse |
| Shoot | Left mouse button |
| Respawn | `R`, `Space`, `Enter`, or the respawn button |
| Exit | `Esc` |

## Connecting to a Public Server

If the server is hosted outside your LAN, use its public IP address or hostname in the connection screen. The server host must expose or forward TCP port `8888` to the machine running `server/main.py`. If a tunneling service is used, enter the TCP host and port supplied by that service.

## Troubleshooting

- **Connection refused:** Confirm that the server is running and that the address and port are correct.
- **Connection timeout:** Check the server firewall, port forwarding, and tunnel status.
- **No game window:** Configure an X server and verify the `DISPLAY` value. Docker containers cannot display GUI applications without a host display server.
- **Missing textures or audio:** Use the published image, which includes the client assets, or build from the `client` directory so the `assets/` folder is copied into the image.
- **Port mismatch:** Use the same port shown by the server. The default is `8888`.

## Build the Image Locally

To build your own image instead of pulling from Docker Hub, run this from the `client` directory:

```bash
docker build -t ursina-client .
```

Then replace `imvickykumar999/ursina-client:latest` in the commands above with `ursina-client`.
