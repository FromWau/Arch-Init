#!/bin/sh
export ZDOTDIR=$HOME/.config/zsh
HISTFILE=~/.zsh_history
setopt appendhistory

# some useful options (man zshoptions)
setopt autocd extendedglob nomatch menucomplete
setopt interactive_comments
stty stop undef		# Disable ctrl-s to freeze terminal.
zle_highlight=('paste:none')

# beeping is annoying
unsetopt BEEP

# completions
autoload -Uz compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
_comp_options+=(globdots)		# Include hidden files.
compinit
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

# Colors
autoload -Uz colors && colors

# Useful Functions
source "$ZDOTDIR/zsh-functions"

# Normal files to source
zsh_add_file "zsh-exports"
zsh_add_file "zsh-aliases"
zsh_add_file "zsh-prompt"

# Plugins
zsh_add_plugin "zsh-users/zsh-autosuggestions"
ZSH_AUTOSUGGEST_STRATEGY=(completion history match_prev_cmd)

zsh_add_plugin "zsh-users/zsh-syntax-highlighting"

zsh_add_plugin "hlissner/zsh-autopair"


# KeyBindings
bindkey  "^[[H"     beginning-of-line
bindkey  "^[[F"     end-of-line
bindkey  "^[[3~"    delete-char
bindkey  ";5C"	    forward-word
bindkey  ";5D"      backward-word
bindkey  "5~"       kill-word
bindkey  "\C-h"     backward-kill-word

# Environment variables set everywhere
export EDITOR="nvim"
export TERMINAL="kitty"
export BROWSER="waterfox-g4"
