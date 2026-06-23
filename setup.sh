#!/bin/bash
# Additional packages
sudo apk add acme bastext idun-zcc zellij
# Setup 'joe' editor for acme
if [ -f "/usr/share/joe/syntax/acme.jsf" ]; then
    sudo mv /usr/share/joe/syntax/acme.jsf /usr/share/joe/syntax/asm.jsf
fi
