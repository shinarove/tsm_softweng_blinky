#!/bin/env bash
set -ex

# setting PICO_SEGGER_IP directly here:
export PICO_SEGGER_IP="tunnel:801012091"
echo "PICO_SEGGER_IP is set to: $PICO_SEGGER_IP"

# build test binary: need to reconfigure it, otherwise a new environment variable is not taken into account
cmake --preset Test
cmake --build --preset app-test

# run tests
# running test from Switch GitLab Server wont work in a reliable way, skipping for now...
#ctest --verbose --test-dir build/Test --output-on-failure
#ctest --verbose --test-dir build/Test --output-on-failure -R Led_1
#ctest --verbose --test-dir build/Test --output-on-failure -R Led_2
#ctest --verbose --test-dir build/Test --output-on-failure -R Led_3
