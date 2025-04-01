#!/bin/bash

set -e  # Exit on error

# Backup existing Neovim configuration
echo "Backing up current Neovim files..."
mv ~/.config/nvim{,.bak}
mv ~/.local/share/nvim{,.bak}
mv ~/.local/state/nvim{,.bak}
mv ~/.cache/nvim{,.bak}

echo "Cloning LazyVim starter..."
git clone https://github.com/LazyVim/starter ~/.config/nvim

# Remove .git folder to allow customization
echo "Removing .git folder..."
rm -rf ~/.config/nvim/.git

# Copy previous config files to new directory
cp ~/.config/nvim.bak/lua/config ~/.config/nvim/lua/
cp ~/.config/nvim.bak/lua/plugins ~/.config/nvim/lua/

echo "Installation complete!"
