#!/bin/zsh -f

PLAY_DEBUG=${PLAY_DEBUG:-0}

[[ $PLAY_DEBUG == 2 ]] && setopt xtrace

PLAY_DIR="${PLAY_DIR:-${0:h}}"
PLAY_GAMES="${PLAY_GAMES:-$PLAY_DIR/games}"
PLAY_TEMPLATES="${PLAY_TEMPLATES:-$PLAY_DIR/templates}"

typeset -A ENV EENV
BIN=$0

source $PLAY_DIR/functions.sh

inherit default

if [[ $1 == "-x" ]]; then
    source $PLAY_GAMES/$2
    setenv
    prepare
    run
else
    GAME=$1
    DGAME="$PLAY_GAMES/$GAME"

    list () {
        out "Games are:"
        for k in $PLAY_GAMES/*(.:t); do
            echo "\t> $k"
        done
    }
    
    if [[ -z $GAME || ! -e $DGAME ]]; then
        [[ ! -e $DGAME ]] && out "Game '$GAME' not found"
        list
        exit 1
    else
        out "Launching '$GAME'"
        source $DGAME
        execute
    fi
fi
