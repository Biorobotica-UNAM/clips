#!/bin/bash
set -e

echo "=== Instalando sistema de planificación CLIPS-ROS2 ==="

# 1. Dependencias de sistema (incluye megatools)
echo "Instalando CLIPS, Boost, herramientas Python y megatools..."
sudo apt update
sudo apt install -y clips libboost-all-dev python3-pip python3-dev megatools

# 2. Binding Python para CLIPS
echo "Instalando clipspy..."
pip3 install clipspy --break-system-packages

# 3. Descargar y extraer modelo nl2cd_qwen7b (si no existe)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL_DIR="$SCRIPT_DIR/nl2cd_qwen7b"
ZIP_FILE="$SCRIPT_DIR/nl2cd_qwen7b.zip"
MEGA_LINK="https://mega.nz/file/mgZj2RhB#jlItPKV1tcmUsrGVGe7jV_BaodccdSnh8aTnRxLbjMA"   # <--- REEMPLAZAR CON EL ENLACE REAL

if [ ! -d "$MODEL_DIR" ]; then
    echo "Descargando modelo nl2cd_qwen7b desde Mega..."
    megadl "$MEGA_LINK" --path "$ZIP_FILE"
    echo "Extrayendo..."
    unzip -q "$ZIP_FILE" -d "$SCRIPT_DIR"
    rm "$ZIP_FILE"
    echo "Modelo descargado y extraído en $MODEL_DIR"
else
    echo "El modelo ya existe en $MODEL_DIR, omitiendo descarga."
fi

echo "✅ Instalación completada."