#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

make clean && make;
./video_viewer forest_sign.mp4
