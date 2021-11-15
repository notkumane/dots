#!/bin/zsh
#
export PATH="$PATH:${$(find ~/.local/bin type -d -printf %p:)%%:}"
export EDITOR="nvim"
export TERMINAL="terminator"
export BROWSER="brave"
if [ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
  exec startx
fi
