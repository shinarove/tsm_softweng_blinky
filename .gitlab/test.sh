#!/bin/env bash
set -ex

# use 'env' or 'printenv' to display current environment variables
# use the following to use an IP address for the J-Link
# export PICO_SEGGER_IP=192.168.1.128
# export PICO_SEGGER_IP=tunnel:801012091

# build test binary
cmake --preset Test
cmake --build --preset app-test

# run all tests
ctest --verbose --test-dir build/Test --timeout 120 --output-on-failure
