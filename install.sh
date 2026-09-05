#!/bin/bash
set -e

INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "${INSTALL_DIR}"

fasm main.asm ramisc
cp -f ramisc "${INSTALL_DIR}/ramisc"
chmod +x "${INSTALL_DIR}/ramisc"

echo "[OK] RamisScript Compiler v0.8.0 установлен в ${INSTALL_DIR}/ramisc"
