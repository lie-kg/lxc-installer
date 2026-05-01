#!/usr/bin/env bash
set -e

echo "[+] Updating system..."
apt update -y && apt upgrade -y

echo "[+] Installing dependencies..."
apt install -y python3 python3-pip lxc

echo "[+] Installing Python library..."
pip3 install --break-system-packages discord.py

echo "[+] Creating bot directory..."
mkdir -p /root

echo "[+] Writing bot.py..."

cat <<'EOF' > /root/bot.py
import discord
from discord.ext import commands
import asyncio
import subprocess
import shlex
import os
import sqlite3
import shutil

TOKEN = os.getenv("DISCORD_TOKEN")
if not TOKEN:
    raise Exception("Missing DISCORD_TOKEN")

BOT_NAME = os.getenv("BOT_NAME", "UnixNodes")
PREFIX = os.getenv("PREFIX", "!")

if not shutil.which("lxc"):
    raise SystemExit("LXC not installed")

def db():
    conn = sqlite3.connect("vps.db")
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = db()
    cur = conn.cursor()
    cur.execute("""
    CREATE TABLE IF NOT EXISTS vps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        container_name TEXT,
        ram TEXT,
        cpu TEXT,
        storage TEXT,
        os_version TEXT,
        status TEXT
    )
    """)
    conn.commit()
    conn.close()

init_db()

def embed(t, d=""):
    return discord.Embed(title=f"{BOT_NAME} - {t}", description=d, color=0x1a1a1a)

async def run(cmd):
    p = await asyncio.create_subprocess_exec(
        *shlex.split(cmd),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    out, err = await p.communicate()
    return out.decode() if p.returncode == 0 else err.decode()

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix=PREFIX, intents=intents)

@bot.command()
async def ping(ctx):
    await ctx.send("pong")

@bot.command()
async def lxc(ctx):
    out = await run("lxc list")
    await ctx.send(f"```\n{out[:1900]}\n```")

@bot.event
async def on_ready():
    print(f"{BOT_NAME} ready")

bot.run(TOKEN)
EOF

echo "[+] Creating systemd service..."

cat <<EOF > /etc/systemd/system/unixbot.service
[Unit]
Description=UnixBot VPS Bot
After=network.target

[Service]
User=root
WorkingDirectory=/root

Environment="DISCORD_TOKEN=YOUR_DISCORD_BOT_TOKEN"
Environment="MAIN_ADMIN_ID=YOUR_ADMIN_ID"

ExecStart=/usr/bin/python3 /root/bot.py

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Activating service..."
systemctl daemon-reload
systemctl enable unixbot
systemctl restart unixbot

echo "[✓] INSTALL COMPLETE"
echo "[!] Edit token here:"
echo "    /etc/systemd/system/unixbot.service"
