#!/bin/bash
set -e

echo "[*] Building RamisScript Compiler v0.7.0..."
fasm main.asm ramisc

echo "[*] Installing ramisc to /usr/local/bin..."
sudo install -m 755 ramisc /usr/local/bin/ramisc

echo "[+] RamisScript successfully installed into system PATH!"
