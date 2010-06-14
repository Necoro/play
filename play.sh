#!/bin/zsh -f

log () {
    echo "*** $@"
}

exp () {
    log "Setting envvar '$1' to '$2'"
    export $1=$2
}

exc () {
    if [[ $1 == "-f" ]]; then
        fork=1
        msg=" (forking)"
        shift
    fi

    log "Executing${msg}:"
    echo $@
    
    sleep 3

    if [[ -n $fork ]]; then
        exec "$@" &!
    else
        eval "$@"
    fi
}

EXPORT () {
    local name=$1
    shift

    for f in $@; do
        eval "$f () { ${name}_${f}; }"
    done
}

inherit () {
    source games/$1
}

typeset -A ENV EENV
BIN=$0

source default

if [[ $1 == "-x" ]]; then
    source games/$2
    setenv
    prepare
    run
else
    GAME=$1

    list () {
        echo "Games are:"
        for k in games/*(.:t); do
            echo "\t> $k"
        done
    }
    
    if [[ -z $GAME || ! -e games/$GAME ]]; then
        [[ ! -e games/$GAME ]] && log "Game '$GAME' not found"
        list
        exit 1
    else
        log "Launching '$GAME'"
        source games/$GAME
        execute
    fi
fi
