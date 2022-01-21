#!/bin/zsh
export EDITOR="nvim"
export TERMINAL="xfce4-terminal"
export BROWSER="brave"
if [ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
  exec startx
fi
