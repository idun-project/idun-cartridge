#!/bin/bash
# Additional packages
sudo pacman -S acme bastext idun-zcc tmux terminus-font
# Setup 'joe' editor for acme
if [ -f "/usr/share/joe/syntax/acme.jsf" ]; then
    sudo mv /usr/share/joe/syntax/acme.jsf /usr/share/joe/syntax/asm.jsf
fi
# Install tmux config and plugins
mkdir -p "$HOME/.config/tmux"
if ! [ -f "$HOME/.config/tmux/tmux.conf" ]; then
    echo "set -g mouse on
    # List of plugins
    set -g @plugin 'tmux-plugins/tpm'
    set -g @plugin 'tmux-plugins/tmux-sensible'
    #set -g @plugin 'catppuccin/tmux'
    set -g @plugin 'tmux-plugins/tmux-yank'
    # Initialize tpm (keep at very bottom of tmux.conf)
    run '~/.config/tmux/plugins/tpm/tpm'" >> "$HOME/.config/tmux/tmux.conf"
    mkdir -p "$HOME/.config/tmux/plugins"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
fi
