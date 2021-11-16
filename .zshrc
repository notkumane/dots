# Lines configured by zsh-newuser-install
cat /home/notkumane/.cache/wal/sequences
eval "$(starship init zsh)"
HISTFILE=~/.cache/zsh/history
HISTSIZE=10000
SAVEHIST=10000
setopt autocd
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/notkumane/.zshrc'
autoload -U colors && colors
autoload -Uz compinit
compinit
# End of lines added by compinstall
alias ls="exa -la"
alias install="sudo pacman -Sy"
alias v="nvim"

source ./zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /home/notkumane/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
