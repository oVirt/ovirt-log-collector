#!/bin/bash -xe
autoreconf -ivf
./configure
make distcheck
