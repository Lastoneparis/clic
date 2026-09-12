#!/bin/bash
# Render a spinning-cube animation with the clic rasterizer and encode a GIF.
set -e
cd "$(dirname "$0")"
mkdir -p build/frames assets

echo "==> building rasterizer + tools"
python3 clicc.py examples/raster.clic -o build/raster.metal
swiftc -O host/clicrun.swift -o build/clicrun
swiftc -O host/mkgif.swift   -o build/mkgif

N=24            # frames
SIZE=360        # px
echo "==> rendering $N frames at ${SIZE}px"
frames=""
for i in $(seq 0 $((N - 1))); do
    ay=$(python3 -c "import math;print(-0.72 + 2*math.pi*$i/$N)")
    f="$PWD/build/frames/f$(printf %02d "$i").png"
    python3 raster_scene.py --ay "$ay" --size "$SIZE" --json runs/_anim.json --out "$f" >/dev/null
    ./build/clicrun runs/_anim.json >/dev/null
    frames="$frames $f"
done

echo "==> encoding assets/cube.gif"
./build/mkgif assets/cube.gif 60 $frames
ls -lh assets/cube.gif | awk '{print "    size:", $5}'
