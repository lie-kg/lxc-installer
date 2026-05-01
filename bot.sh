#!/usr/bin/env bash
set -e

echo "[+] Updating system..."
apt update -y

echo "[+] Installing dependencies..."
apt install python3 python3-pip lxc -y

echo "[+] Installing Python requirements..."
pip3 install discord.py

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

DISCORD_TOKEN = os.getenv("DISCORD_TOKEN")
if not DISCORD_TOKEN:
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

vps_data = {}

def embed(t, d=""):
    return discord.Embed(title=f"{BOT_NAME} - {t}", description=d, color=0x1a1a1a)

async def run(cmd):
    p = await asyncio.create_subprocess_exec(*shlex.split(cmd),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE)
    out, err = await p.communicate()
    if p.returncode != 0:
        return err.decode()
    return out.decode()

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix=PREFIX, intents=intents)

class ManageView(discord.ui.View):
    def __init__(self, uid, vps):
        super().__init__()
        self.uid = uid
        self.vps = vps
        self.index = 0

    async def action(self, interaction, act):
        v = self.vps[self.index]
        name = v["container_name"]

        if act == "start":
            await run(f"lxc start {name}")
        elif act == "stop":
            await run(f"lxc stop {name}")

        await interaction.response.send_message(f"{act} done", ephemeral=True)

class ReinstallView(discord.ui.View):
    def __init__(self, c, vps):
        super().__init__()
        self.c = c
        self.vps = vps

        self.select = discord.ui.Select(
            options=[
                discord.SelectOption(label="Ubuntu 22.04", value="ubuntu:22.04"),
                discord.SelectOption(label="Ubuntu 24.04", value="ubuntu:24.04"),
                discord.SelectOption(label="Debian 12", value="images:debian/12"),
            ]
        )

        self.select.callback = self.reinstall
        self.add_item(self.select)

    async def reinstall(self, interaction):
        osv = self.select.values[0]
        v = self.vps

        ram = v["ram"].replace("GB","")
        cpu = v["cpu"]

        await interaction.response.send_message("Reinstalling...", ephemeral=True)

        await run(f"lxc stop {self.c} || true")
        await run(f"lxc delete {self.c} || true")

        await run(f"lxc launch {osv} {self.c}")
        await run(f"lxc config set {self.c} limits.memory {ram}GB")
        await run(f"lxc config set {self.c} limits.cpu {cpu}")

        await interaction.followup.send("Done", ephemeral=True)

@bot.command()
async def ping(ctx):
    await ctx.send("pong")

@bot.command()
async def myvps(ctx):
    await ctx.send(embed=embed("VPS loaded"))

@bot.command()
async def manage(ctx):
    await ctx.send(embed=embed("Manage VPS"))

@bot.event
async def on_ready():
    print(f"{BOT_NAME} ready")

bot.run(DISCORD_TOKEN)
EOF

echo "[+] Creating systemd service..."

cat <<EOF > /etc/systemd/system/unixbot.service
[Unit]
Description=UnixBot
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

echo "[+] Enabling service..."
systemctl daemon-reload
systemctl enable unixbot
systemctl restart unixbot

echo "[✓] INSTALL COMPLETE"
echo "Edit token in /etc/systemd/system/unixbot.service"
