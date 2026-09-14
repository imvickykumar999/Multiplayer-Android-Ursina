"""
Server script for hosting games
"""

import socket
import json
import time
import random
import threading
import subprocess
try:
    import psutil
except ImportError:
    psutil = None
from art import *

try:
    from colorama import Fore, Style, init
    init(autoreset=True)
    RED = Fore.RED + Style.BRIGHT
    BLUE = Fore.BLUE + Style.BRIGHT
    RESET = Style.RESET_ALL
except ImportError:
    RED = ""
    BLUE = ""
    RESET = ""


PORT = 8888 # this should be same as you define in playit.gg dashboard
ADDR = "0.0.0.0"
MAX_PLAYERS = 10
MAX_HEALTH = 250
MSG_SIZE = 2048

# Setup server socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind((ADDR, PORT))
s.listen(MAX_PLAYERS)

players = {}

def generate_id(player_list: dict, max_players: int):
    """
    Generate a unique identifier

    Args:
        player_list (dict): dictionary of existing players
        max_players (int): maximum number of players allowed

    Returns:
        str: the unique identifier
    """

    while True:
        unique_id = str(random.randint(1, max_players))
        if unique_id not in player_list:
            return unique_id


def handle_messages(identifier: str):
    client_info = players[identifier]
    conn: socket.socket = client_info["socket"]
    username = client_info["username"]

    while True:
        try:
            msg = conn.recv(MSG_SIZE)
        except ConnectionResetError:
            break

        if not msg:
            break

        msg_decoded = msg.decode("utf8")

        try:
            left_bracket_index = msg_decoded.index("{")
            right_bracket_index = msg_decoded.index("}") + 1
            msg_decoded = msg_decoded[left_bracket_index:right_bracket_index]
        except ValueError:
            continue

        try:
            msg_json = json.loads(msg_decoded)
        except Exception as e:
            print(f"{RED}[!] Error: {e}{RESET}")
            continue

        print(f"{BLUE}[>] Received message from player {RED}{username}{BLUE} with ID {RED}{identifier}{RESET}")

        if msg_json["object"] == "player":
            players[identifier]["position"] = msg_json["position"]
            players[identifier]["rotation"] = msg_json["rotation"]
            players[identifier]["health"] = msg_json["health"]

            # Make player invisible if health is 0
            if msg_json["health"] <= 0:
                players[identifier]["visible"] = False
            else:
                players[identifier]["visible"] = True

        elif msg_json["object"] == "respawn":
            players[identifier]["position"] = msg_json["position"]
            players[identifier]["health"] = msg_json["health"]
            players[identifier]["visible"] = True

            # Broadcast respawn event to other players
            respawn_message = json.dumps({
                "object": "player_respawn",
                "id": identifier,
                "position": players[identifier]["position"],
                "health": players[identifier]["health"]
            })

            for player_id in list(players):
                if player_id != identifier:
                    player_info = players[player_id]
                    player_conn: socket.socket = player_info["socket"]
                    try:
                        player_conn.sendall(respawn_message.encode("utf8"))
                    except OSError:
                        pass
            continue

        elif msg_json["object"] == "health_update":
            target_id = str(msg_json.get("id"))
            if target_id in players:
                players[target_id]["health"] = msg_json["health"]
                if msg_json["health"] <= 0:
                    players[target_id]["visible"] = False
                else:
                    players[target_id]["visible"] = True

        # Tell other players about player moving or visibility change
        for player_id in list(players):
            if player_id != identifier:
                player_info = players[player_id]
                player_conn: socket.socket = player_info["socket"]
                try:
                    player_conn.sendall(msg_decoded.encode("utf8"))
                except OSError:
                    pass


    # Tell other players about player leaving
    for player_id in list(players):
        if player_id != identifier:
            player_info = players[player_id]
            player_conn: socket.socket = player_info["socket"]
            try:
                player_conn.send(json.dumps({"id": identifier, "object": "player", "joined": False, "left": True}).encode("utf8"))
            except OSError:
                pass

    print(f"{RED}[-] Player {BLUE}{username}{RED} with ID {BLUE}{identifier}{RED} has left the game...{RESET}")
    del players[identifier]
    conn.close()


def get_tailscale_ip():
    """Detect Tailscale IPv4 address if Tailscale is running."""
    if psutil:
        try:
            for iface, addrs in psutil.net_if_addrs().items():
                if 'tailscale' in iface.lower():
                    for a in addrs:
                        if getattr(a, 'family', None) == socket.AF_INET and not a.address.startswith('127.'):
                            return a.address
        except Exception:
            pass

    try:
        hostname = socket.gethostname()
        for ip in socket.gethostbyname_ex(hostname)[2]:
            parts = [int(p) for p in ip.split('.') if p.isdigit()]
            if len(parts) == 4 and parts[0] == 100 and (64 <= parts[1] <= 127):
                return ip
    except Exception:
        pass

    try:
        res = subprocess.run(['tailscale', 'ip', '-4'], capture_output=True, text=True, timeout=2)
        if res.returncode == 0:
            ip = res.stdout.strip().splitlines()[0].strip()
            if ip:
                return ip
    except Exception:
        pass

    return None


def get_local_ip():
    """Get local network IPv4 address."""
    try:
        s_test = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s_test.settimeout(0.5)
        s_test.connect(('8.8.8.8', 80))
        ip = s_test.getsockname()[0]
        s_test.close()
        if ip and not ip.startswith('127.'):
            return ip
    except Exception:
        pass
    try:
        return socket.gethostbyname(socket.gethostname())
    except Exception:
        return '127.0.0.1'


def main():
    tailscale_ip = get_tailscale_ip()
    local_ip = get_local_ip()

    # Prioritize Tailscale IP if active, otherwise local LAN IP
    server_addr = tailscale_ip if tailscale_ip else local_ip

    print(f"\n{BLUE}{'=' * 50}{RESET}")
    print(f"{BLUE}[*] Server started, listening on 0.0.0.0:{PORT}...{RESET}")
    if tailscale_ip:
        print(f"{BLUE}[*] Tailscale IP  = {RED}{tailscale_ip}{RESET} (Use this for Tailscale)")
        print(f"{BLUE}[*] Local LAN IP  = {RED}{local_ip}{RESET} (Use this for same Wi-Fi only)")
    else:
        print(f"{BLUE}[*] Local IP      = {RED}{local_ip}{RESET}")
    print(f"{BLUE}{'=' * 50}\n{RESET}")
    for i, line in enumerate(text2art(server_addr).splitlines()):
        color = BLUE if i % 2 == 0 else RED
        print(f"{color}{line}{RESET}")
    print()

    while True:
        # Accept new connection and assign unique ID
        conn, addr = s.accept()
        new_id = generate_id(players, MAX_PLAYERS)
        conn.send(new_id.encode("utf8"))

        try:
            username = conn.recv(MSG_SIZE).decode("utf8")
        except UnicodeDecodeError as e:
            print(f"{RED}[!] Failed to decode username: {e}{RESET}")
            conn.close()
            continue

        new_player_info = {"socket": conn, "username": username, "position": (0, 1, 0), "rotation": 0, "health": MAX_HEALTH, "visible": True}

        # Tell existing players about new player
        for player_id in list(players):
            if player_id != new_id:
                player_info = players[player_id]
                player_conn: socket.socket = player_info["socket"]
                try:
                    player_conn.send(json.dumps({
                        "id": new_id,
                        "object": "player",
                        "username": new_player_info["username"],
                        "position": new_player_info["position"],
                        "health": new_player_info["health"],
                        "joined": True,
                        "left": False
                    }).encode("utf8"))
                except OSError:
                    pass

        # Tell new player about existing players
        for player_id in list(players):
            if player_id != new_id:
                player_info = players[player_id]
                try:
                    conn.send(json.dumps({
                        "id": player_id,
                        "object": "player",
                        "username": player_info["username"],
                        "position": player_info["position"],
                        "health": player_info["health"],
                        "joined": True,
                        "left": False
                    }).encode("utf8"))
                    time.sleep(0.1)
                except OSError:
                    pass

        # Add new player to players list, effectively allowing it to receive messages from other players
        players[new_id] = new_player_info

        # Start thread to receive messages from client
        msg_thread = threading.Thread(target=handle_messages, args=(new_id,), daemon=True)
        msg_thread.start()

        print(f"{BLUE}[+] New connection from {RED}{addr}{BLUE}, assigned ID: {RED}{new_id}{RESET}")


if __name__ == "__main__":
    try:
        while True:
            try:
                main()
            except KeyboardInterrupt:
                print(f"\n{RED}[!] Server stopped manually.{RESET}")
                break  # Allow graceful shutdown on Ctrl+C
            except SystemExit:
                print(f"\n{RED}[!] System exit triggered.{RESET}")
                break
            except Exception as e:
                print(f"\n{RED}[!] Server crashed with error: {e}{RESET}")
                print(f"{RED}[!] Restarting server in 5 seconds...\n{RESET}")
                time.sleep(5)
    finally:
        s.close()
