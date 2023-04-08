#!/bin/bash
if ! [ -f "/usr/bin/acme" ]; then
	cd acme
	make
	sudo make install
	cd ..
fi
cd cbm && make
cd ..
cd samples && make
cd ..
mkdir -p ../idun-sys/sys
cp sys/* ../idun-sys/sys/