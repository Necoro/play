#!/bin/zsh -f

# initialization {{{
PLAY_DEBUG=${PLAY_DEBUG:-0}

[[ $PLAY_DEBUG == 2 ]] && setopt xtrace

PLAY_DIR="${PLAY_DIR:-${0:h}}"
PLAY_GAMES="${PLAY_GAMES:-$PLAY_DIR/games}"
PLAY_TEMPLATES="${PLAY_TEMPLATES:-$PLAY_DIR/templates}"

typeset -A ENV EENV
BIN=$0
# }}}

# global functions {{{
out () {
    echo ">>> $@"
}

log () {
    [[ $PLAY_DEBUG > 0 ]] && echo "*** $@"
}

die () {
    out "*** ERROR: $@"
    exit 1
}

exp () {
    log "Setting envvar '$1' to '$2'"
    export $1=$2
}

exc () {
    cmd="eval"

    if [[ $1 == "-e" ]]; then
        cmd="exec"
        shift
    fi

    log "Executing (using '$cmd'):"
    log "> $@"

    $cmd "$@"
}

EXPORT () {
    local name=$1
    shift

    for f in $@; do
        eval "$f () { ${name}_${f}; }"
    done
}

inherit () {
    zparseopts -D e=nonfatal
    
    if [[ ! -e $PLAY_TEMPLATES/$1 ]]; then
        if [[ -n $nonfatal ]]; then
            log "Template '$1' not found"
            return
        else
            die "Template '$1' not found"
        fi
    fi
    
    source $PLAY_TEMPLATES/$1
}

load () {
    inherit -e default

    source "$PLAY_GAMES/$1"
}
# }}}

# default template {{{

# exporting variables
EENV[WINEPREFIX]='eval echo $PREFIX'
ENV[DISPLAY]=":1"

PREFIX="~/.wine"

# functions
play_execute () {
    exc -e startx $BIN -x $GAME -- :1 -ac -br -quiet ${=EXARGS}
}

play_prepare () {
    # set display size
    [[ -n $SIZE ]] && exc xrandr -s $SIZE
}

play_setenv () {
    for e v in ${(kv)ENV}; do
        exp $e $v
    done
    
    for e v in ${(kv)EENV}; do
        exp $e `eval $v`
    done
}

play_run () {
    # start game
    exc wine start $GPATH "$ARGS"
    
    # wait for wine to shutdown
    exc wineserver -w
}

play_cleanup () {
}

EXPORT play execute prepare setenv run cleanup
# }}}

if [[ $1 == "-x" ]]; then
    load $2
    setenv
    prepare
    run
    cleanup
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
        load $GAME
        execute
    fi
fi

# vim: foldmethod=marker
