#!/bin/bash
cd "$(dirname "$0")"
echo "Downloading food photos into the Images/photos folder..."
echo
python3 download_images.py
echo
read -n 1 -s -r -p "Press any key to close"
