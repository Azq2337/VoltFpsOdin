#!/usr/bin/env bash
set -e

mkdir -p build
odin build src/main -out:build/main -debug -o:none

