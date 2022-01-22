#zsh-config
source /home/notkumane/.zsh/syntax-highlighting/zsh-syntax-highlighting.zsh
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
    builtin cd "$@" && exa -F
    }
alias v="sudo nvim"
alias ls="exa -la"
alias rr="v ~/.config/i3/config"
