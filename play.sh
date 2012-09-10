#!/bin/zsh -f

# variables gathered from the environment {{{1

# debugging
# 0 -> off
# 1 -> log messages (mostly 'eval' calls) and wine debug
# 2 -> 1 + xtrace
PLAY_DEBUG=${PLAY_DEBUG:-0}

[[ $PLAY_DEBUG == 2 ]] && setopt xtrace

# directory we are in
PLAY_DIR="${PLAY_DIR:-${0:h}}"

# directory of installed games
PLAY_GAMES="${PLAY_GAMES:-$PLAY_DIR/installed}"

# directory of templages
PLAY_TEMPLATES="${PLAY_TEMPLATES:-$PLAY_DIR/templates}"

# binary to echo
PLAY_BIN="${PLAY_BIN:-$0}"

# initialization of internal variables {{{1

# environment dictionaries
# ENV: name to value
# EENV: name to string, which is evaluated into the value
typeset -A ENV EENV

# current binary -- complete path
BIN=${0:A}

# global functions {{{1

# print passed arguments to stderr
# if first arg is "-n", do not append newline
out () {
    zparseopts -D n=n

    echo $n ">>> $*" >&2
}

# print passed arguments to stderr ONLY if PLAY_DEBUG is nonzero
log () {
    [[ $PLAY_DEBUG > 0 ]] && echo "*** $*" >&2
}

# die with a supplied error message
die () {
    out "*** ERROR: $*"
    exit 1
}

# exports $1=$2
exp () {
    log "Setting envvar '$1' to '$2'"
    export $1=$2
}

# executes the passed command including arguments 
# (as individual parameters to this function)
# if first arg is "-e" use exec instead of eval
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

# exports the given key with its value in $ENV
# NB: it also exports empty values
set_env () {
    local k=$1
    local v=${ENV[$k]}

    v=${(P)${:-PLAY_ENV_$k}:-$v}
    exp $k $v
}

# exports the given key with its value in $EENV
# this implies, that the value is evaluated!
# NB: it also exports empty values
set_eenv () {
    local k=$1
    local v=${EENV[$k]}
    v=${(P)${:-PLAY_EENV_$k}:-$v}
    exp $k `eval $v`
}

# inherits a specified template
# i.e. source it :)
# if first argument is "-e", do not die if template could not be found
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

# function, that is used to _export_ the default phase functions
# i.e. 'EXPORT bla prepare' will set bla_prepare as the function being called
# on prepare()
EXPORT () {
    local name=$1
    shift

    for f in $@; do
        eval "$f () { ${name}_${f}; }"
    done
}

# default enviroment {{{1

EENV[WINEPREFIX]='eval echo $PREFIX'
ENV[DISPLAY]=":1"

# phase functions {{{1

# to be removed
play_execute () {
    exc -e startx $BIN -x $GAME -- $DISPLAY -ac -br -quiet ${=EXARGS}
}

# populate the environment
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

# run wine and therefore the game
play_run () {
    # cd into dir
    local dir="$(exc winepath -u $GPATH)"
    exc cd "${dir:h}"

    # start game
    exc wine start ${dir:t} "$ARGS"
    
    # wait for wine to shutdown
    exc wineserver -w
}

# prepare things for the game, e.g. mount ISOs
play_prepare () {
    # set display size
    [[ -n $SIZE ]] && exc xrandr -s $SIZE
}

# cleanup after yourself
play_cleanup () {
}

EXPORT play execute prepare setenv run cleanup

# internal functions {{{1

_load () { # {{{2
    inherit -e default

    source $GAME_PATH
}

_list () { # {{{2
    out "The installed games are:"
    # on -> sort alphabetically
    # N -> NULL_GLOB -> no error message if no match
    # .,@ -> regular files or symbolic links (, == or)
    # :t -> modifier: only basename
    for k in $PLAY_GAMES/*(onN.,@:t); do
        echo "\t> $k"
    done
}

_new () { # {{{2
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

_execute () { # {{{2
    _load
    prepare
    run
    cleanup
}

_run () { #{{{2
    declare -xg GAME=$1
    declare -xg GAME_PATH="$PLAY_GAMES/$GAME"

    if [[ $GAME == new ]]; then
        shift
        _new "$@"
    elif [[ -z $GAME || ! -e $GAME_PATH ]]; then
        [[ ! -e $GAME_PATH ]] && out "Game '$GAME' not found"
        _list
        exit 1
    else
        out "Launching '$GAME'"
        _load
        setenv
        execute
    fi
}

# main {{{1
if [[ $1 == "-x" ]]; then
    _execute
else
    _run "$@"
fi
# }}}1

# vim: foldmethod=marker
