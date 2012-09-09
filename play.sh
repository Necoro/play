#!/bin/zsh -f

# initialization {{{
PLAY_DEBUG=${PLAY_DEBUG:-0}

[[ $PLAY_DEBUG == 2 ]] && setopt xtrace

PLAY_DIR="${PLAY_DIR:-${0:h}}"
PLAY_GAMES="${PLAY_GAMES:-$PLAY_DIR/installed}"
PLAY_TEMPLATES="${PLAY_TEMPLATES:-$PLAY_DIR/templates}"

typeset -A ENV EENV
BIN=${0:A}

PLAY_BIN=${PLAY_BIN:-$0}
# }}}

# global functions {{{
out () {
    if [[ $1 == "-n" ]]; then
        n="-n"
        shift
    fi

    echo $n ">>> $*" >&2
}

log () {
    [[ $PLAY_DEBUG > 0 ]] && echo "*** $*" >&2
}

die () {
    out "*** ERROR: $*"
    exit 1
}

exp () {
    log "Setting envvar '$1' to '$2'"
    export $1=$2
}

exc () {
    local cmd="eval"

    if [[ $1 == "-e" ]]; then
        cmd="exec"
        shift
    fi

    log "Executing (using '$cmd'):"
    log "> $*"

    if [[ $cmd == exec ]]; then
        exec $@
    else
        $*
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

set_env () {
    local k=$1
    local v=${ENV[$k]}

    v=${(P)${:-PLAY_ENV_$k}:-$v}
    exp $k $v
}

set_eenv () {
    local k=$1
    local v=${EENV[$k]}
    v=${(P)${:-PLAY_EENV_$k}:-$v}
    exp $k `eval $v`
}

# }}}

# default template {{{

# exporting variables
EENV[WINEPREFIX]='eval echo $PREFIX'
ENV[DISPLAY]=":1"

# functions
play_execute () {
    exc -e startx $BIN -x $GAME -- $DISPLAY -ac -br -quiet ${=EXARGS}
}

play_prepare () {
    # set display size
    [[ -n $SIZE ]] && exc xrandr -s $SIZE
}

play_setenv () {
    # default PREFIX
    PREFIX=${PREFIX:-$GAME}

    # set environment
    # ENV is set directly -- EENV is evaluated
    # it is possible to override ENV[p] by PLAY_ENV_p
    # (and similar for EENV)
    for e in ${(k)ENV}; do
        set_env $e
    done
    
    for e in ${(k)EENV}; do
        set_eenv $e
    done
}

play_run () {
    # cd into dir
    local dir="$(exc winepath -u $GPATH)"
    exc cd "${dir:h}"

    # start game
    exc wine start ${dir:t} "$ARGS"
    
    # wait for wine to shutdown
    exc wineserver -w
}

play_cleanup () {
}

EXPORT play execute prepare setenv run cleanup
# }}}

_list () {
    out "The installed games are:"
    # on -> sort alphabetically
    # N -> NULL_GLOB -> no error message if no match
    # .,@ -> regular files or symbolic links (, == or)
    # :t -> modifier: only basename
    for k in $PLAY_GAMES/*(onN.,@:t); do
        echo "\t> $k"
    done
}

_new () {
    local GAME=$1
    local DGAME="$PLAY_GAMES/$GAME"
    local GPATH=$2
    local PREFIX=${${3}:-$GAME}
    local convpath

    [[ -e $DGAME ]] && die "Game file already existing -- aborting!"

    inherit -e default
    set_eenv WINEPREFIX
    set_env WINEDEBUG
    
    [[ ! -e $WINEPREFIX ]] && die "Specified prefix '$PREFIX' does not exist"

    convpath="$(exc winepath -u $GPATH)"

    [[ ! -e $convpath ]] && die "Specified executable does not exist"

    [[ -n $3 ]] && GPREFIX="PREFIX=\"$3\""

    # everything is fine -- write file
    cat > $DGAME << EOF
$GPREFIX
GPATH="$GPATH"

# vim:ft=sh
EOF

    out "New game successfully created"
    out "You can play it by '$PLAY_BIN $GAME'"
    out -n "Play it now? [y/n] "
    if read -q; then
        echo
        exc -e $BIN $GAME
    else
        echo
    fi
}

_execute () {
    declare -g GAME=$1
    
    load $GAME
    prepare
    run
    cleanup
}

_run () {
    declare -g GAME=$1
    local DGAME="$PLAY_GAMES/$GAME"

    if [[ $GAME == new ]]; then
        shift
        _new "$@"
    elif [[ -z $GAME || ! -e $DGAME ]]; then
        [[ ! -e $DGAME ]] && out "Game '$GAME' not found"
        _list
        exit 1
    else
        out "Launching '$GAME'"
        load $GAME
        setenv
        execute
    fi
}

if [[ $1 == "-x" ]]; then
    _execute $2
else
    _run "$@"
fi

# vim: foldmethod=marker
