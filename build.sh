#!/bin/env bash
set -ex

# build all presets
echo "building presets"
cmake --preset Debug
cmake --build --preset app-debug
cmake --preset Release
cmake --build --preset app-release
cmake --preset Test
cmake --build --preset app-test

# generate documentation
echo "building documentation"
cd doxy/
doxygen Doxyfile
