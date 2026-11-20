#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

make clean && make
./video_viewer csi://0 display://0 --input-flip=rotate-180