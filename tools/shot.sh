#!/usr/bin/env bash
# Uso: tools/shot.sh out.png scena frames [query]   (solo per le prove)
cd "$(dirname "$0")/.."
G="${GODOT:-$HOME/godot/Godot_v4.5.1-stable_linux.x86_64}"
timeout 90 xvfb-run -a -s "-screen 0 1200x2000x24" "$G" --rendering-driver opengl3 --resolution ${RES:-540x960} -- "shot=$1" "scene=res://scenes/$2.tscn" "frames=$3" "q=$4" 2>&1 | grep -E "SCRIPT|ERROR" | grep -v cleanup | head -5
