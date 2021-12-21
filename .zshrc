# Lines configured by zsh-newuser-install
cat /home/notkumane/.cache/wal/sequences
eval "$(thefuck --alias)"
eval "$(starship init zsh)"
HISTFILE=~/.cache/zsh/history
HISTSIZE=10000
SAVEHIST=10000
setopt autocd
bindkey -e


zstyle :compinstall filename '/home/notkumane/.zshrc'
autoload -U colors && colors

autoload -U compinit && compinit -u
zstyle ':completion:*' menu select
# Auto complete with case insenstivity
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
compinit

alias cf="v ~/.config/conky/conky.conf"
alias ls="exa -la"
alias v="sudo nvim"
alias rr="nvim ~/.config/i3/config"
alias gitsync="~/Scripts/sync.sh"
source /home/notkumane/Scripts/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
