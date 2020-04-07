#!/bin/bash
make clean-all &&
cd lua-5.4.0-beta && make -j4 linux && cd ..
cd lua-5.4.0-beta-nolibs && make -j4 linux && cd ..
make run
