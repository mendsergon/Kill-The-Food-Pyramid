#!/bin/sh
printf '\033c\033]0;%s\a' RoboPlat
base_path="$(dirname "$(realpath "$0")")"
"$base_path/KILL THE FOOD PYRAMID.x86_64" "$@"
