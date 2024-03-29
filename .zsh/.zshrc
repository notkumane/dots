#zsh-config
eval "$(starship init zsh)"
HISTFILE=~/.zsh/history
HISTSIZE=10000
SAVEHIST=10000
setopt autocd
autoload -U colors && colors
autoload -U compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zmodload zsh/complist
compinit
_comp_options+=(globdots)

bindkey -v
export KEYTIMEOUT=1

function cd {
    builtin cd "$@" && exa -a -s type --icons --grid
    }
alias v="sudo nvim"
alias ls="exa -a -s type --icons --grid"
alias rr="v ~/.config/i3/config"
