#!/bin/bash
set -e

echo "=== Instalando sistema de planificación CLIPS-ROS2 ==="

# 1. Dependencias de sistema
echo "Instalando CLIPS, Boost y herramientas Python..."
sudo apt update
sudo apt install -y clips libboost-all-dev python3-pip python3-dev

# 2. Binding Python para CLIPS
echo "Instalando clipspy..."
pip3 install clipspy --break-system-packages

echo "✅ Instalación completada."