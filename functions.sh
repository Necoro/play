out () {
    echo ">>> $@"
}

log () {
    [[ $PLAY_DEBUG > 0 ]] && echo "*** $@"
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

    if [[ $PLAY_DEBUG > 0 ]]; then
        log "Executing (using '$cmd'):"
        log "> $@"
        
        sleep 3
    fi

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
    source $PLAY_TEMPLATES/$1
}
