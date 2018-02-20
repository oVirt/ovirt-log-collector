#!/bin/bash -xe
autoreconf -ivf
./configure
make distcheck

./automation/build-artifacts.sh
