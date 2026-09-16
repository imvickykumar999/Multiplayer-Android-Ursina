# Ursina FPS - Flutter Android Client

A cross-platform Flutter Android mobile client for the multiplayer 3D FPS game [Multiplayer-Android-Ursina](https://github.com/imvickykumar999/Multiplayer-Android-Ursina).

## 🚀 Features

- **Direct Server Connection**: Pre-configured with default server address `game.24x7stream.shop` on port `8888`.
- **Identical UI & UX**:
  - Fullscreen lobby screen featuring `background.jpg` and ambient background music (`music.mp3`).
  - Color-coded username selector matching the 10 distinct player palettes (`Blue`, `Green`, `Orange`, `Purple`, `Yellow`, `Red`, `Turquoise`, `Pink`, `Cyan`, `Lime`).
  - Dynamic color indicator dot previewing player color.
  - Port and server address fields.
  - Green "Play" and Red "Close" buttons.
- **3D Real-time Combat Arena**:
  - Custom 3D software rendering engine built for mobile performance.
  - Multi-level arena: Ground floor (40x40 checkerboard), 1st floor upper deck with central atrium, stairs, support pillars, railings, and tactical cover walls.
  - Real-time multiplayer synchronization over TCP sockets: player positions, rotations, bullet trajectory events, health updates, and respawns.
  - Floating billboarded name tags with health bars above other players.
  - Viewmodel gun matching your player color with firing recoil and reload animation.
  - Shooting sound effects (`bullet.mp3`) and muzzle flash.
- **Mobile Touch Controls**:
  - **Left Virtual Joystick**: Smooth movement (forward, backward, strafing).
  - **Right Touch Look Area**: Pan/drag to aim (pitch and yaw).
  - **Action Buttons**: Shoot (primary red target), Jump (blue arrow), and Reload (orange refresh).
  - **Top HUD**: Health bar (`250/250 HP`), Ammo counter (`15/15`), and reloading countdown timer.
  - **Death & Respawn Screen**: Auto-respawn countdown with manual `RESPAWN` button.

## 📱 APK File Location

The Android APK is built and ready for installation:

- **Quick access**: `game/ursina-fps.apk`
- **Build output**: `game/build/app/outputs/flutter-apk/app-debug.apk`

### Installing on Android Device

Connect your phone via USB with USB Debugging enabled:

```powershell
adb install -r C:\Users\surface\Documents\GitHub\Multiplayer-Android-Ursina\game\ursina-fps.apk
```

Or copy `ursina-fps.apk` to your phone storage and tap to install.

## 💻 Running with Flutter

To run or debug the app directly:

```powershell
cd C:\Users\surface\Documents\GitHub\Multiplayer-Android-Ursina\game
flutter run
```
