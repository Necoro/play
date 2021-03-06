#!/bin/zsh -f

# ZSH setup {{{1

# make the $functions and $functracs variables available
zmodload -F zsh/parameter +p:functions +p:functrace

# variables gathered from the environment {{{1

# debugging
# 0 -> off (+ WINEDEBUG=-all)
# 1 -> log messages (mostly 'eval' calls) (+ WINEDEBUG=-all)
# 2 -> log messages (+ default WINEDEBUG)
# 3 -> 2 + xtrace
PLAY_DEBUG=${PLAY_DEBUG:-0}

[[ $PLAY_DEBUG == 3 ]] && setopt xtrace

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

# current template -- used for EXPORT
CUR_TEMPLATE=play

# array of loaded templates
declare -a TEMPLATES

# Array of phases
PHASES=(setenv prepare setupX startX run cleanup)
declare -r PHASES
declare -A PHASE_FUNS

# global functions {{{1

# print passed arguments to stderr
# if first arg is "-n", do not append newline
out () {
    zparseopts -D n=n

    echo $n ">>> $*" >&2
}

# print passed arguments to stderr ONLY if PLAY_DEBUG is nonzero
log () {
    (( PLAY_DEBUG > 0 )) && echo "*** $*" >&2
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
# if first arg is "-b" background the job
exc () {
    local cmd="eval" bg

    if [[ $1 == "-e" ]]; then
        cmd="exec"
        shift
    elif [[ $1 == "-b" ]]; then
        bg=" in background"
        shift
    fi

    log "Executing (using '$cmd'$bg):"
    log "> $*"

    if [[ $cmd == exec ]]; then
        exec $@
    elif [[ -n $bg ]]; then
        $* &
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
    
    for templ; do
        local old_templ=$CUR_TEMPLATE

        CUR_TEMPLATE=$templ

        if [[ ! -e $PLAY_TEMPLATES/$templ ]]; then
            if [[ -n $nonfatal ]]; then
                log "Template '$templ' not found"
                return
            else
                die "Template '$templ' not found"
            fi
        fi

        source $PLAY_TEMPLATES/$templ

        TEMPLATES+=$CUR_TEMPLATE

        CUR_TEMPLATE=$old_templ
    done
}

# returns true iff the given template has been loaded
loaded () {
    (( $+TEMPLATES[(r)$1] ))
}

# run the chain of functions of the templates for the phase
# it gets called from
# Param: -r -> remove the phase of this template
super () {
    zparseopts -D r+:=removes
    local caller=$funcstack[2] funs=

    if (( $+PHASES[(r)$caller] )); then
        removes=(${removes/-r/})
        if [[ -n $removes ]]; then
            removes=(${removes/%/_$caller})
            funs=(${(s.:.)PHASE_FUNS[$caller]})
            funs=(${funs:|removes})
            eval ${(F)funs}
        else
            _$caller
        fi
    else
        log "'super' called from non-phase '$caller'"
    fi
}

# function, that is used to _export_ the default phase functions
# i.e. 'EXPORT prepare' in template 'bla' will add bla_prepare to the functions being called
# on prepare()
# NB: this relies on CUR_TEMPLATE being correct -- DO NOT set CUR_TEMPLATE in a game file!
EXPORT () {
    local override
    local fun

    for phase; do
        if [[ $phase == *_override ]]; then
            override=1
            phase=${phase%_override}
        else
            override=0
        fi

        fun=${CUR_TEMPLATE}_${phase}

        if (( $+PHASES[(r)$phase] )); then
            if (( override )); then
                PHASE_FUNS[$phase]=$fun
            else
                PHASE_FUNS[$phase]+=:$fun
            fi
        else
            log "Invalid phase function '$phase' exported in $CUR_TEMPLATE"
        fi
    done
}

OVERRIDE () {
    EXPORT ${argv/%/_override}
}

# default enviroment {{{1

ENV[DISPLAY]=":1"

(( PLAY_DEBUG <= 1 )) && ENV[WINEDEBUG]="-all"

# phase functions {{{1

# starts a new X
# if overridden, this MUST call `$BIN --in-X`
play_startX () {
    exc startx $BIN --in-X $GAME -- $DISPLAY -ac -br -quiet ${=X_ARGS}
}

# populate the environment
play_setenv () {
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

# run game
play_run () {
    exc $EXE "$ARGS"
}

# manipulate the newly created X instance
play_setupX () {
    # set display size
    [[ -n $SIZE ]] && exc xrandr -s $SIZE
}

# prepare things for the game, e.g. mount ISOs
play_prepare () {
}

# cleanup after yourself
play_cleanup () {
}

OVERRIDE $PHASES[@]

for phase in $PHASES; do
    functions[$phase]="_$phase \$@"
done

# internal functions {{{1

_load () { # {{{2
    inherit -e default
    source $GAME_PATH

    local funs

    for phase in $PHASES; do
        funs=(${(s.:.)PHASE_FUNS[$phase]})
        funs=(${funs/%/ \$@})
        functions[_$phase]=${(F)funs}
    done
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
    local EXE=$2
    local PREFIX=${${3}:-$GAME}
    local convpath

    [[ -e $DGAME ]] && die "Game file already existing -- aborting!"

    inherit -e default wine
    setenv
    
    [[ ! -e $WINEPREFIX ]] && die "Specified prefix '$PREFIX' does not exist"

    convpath="$(exc winepath -u $EXE)"

    [[ ! -e $convpath ]] && die "Specified executable does not exist"

    [[ -n $3 ]] && GPREFIX="PREFIX=\"$3\""

    # everything is fine -- write file
    cat > $DGAME << EOF
inherit wine

$GPREFIX
EXE="$EXE"

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

_continue_in_X () { # {{{2
    _load
    setupX
    run
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
        if [[ $2 == "cleanup" ]]; then
            out "Cleaning up after '$GAME'"
            _load
            setenv
            cleanup force
        else
            out "Launching '$GAME'"
            _load
            setenv
            prepare
            startX
            cleanup
        fi
    fi
}

# main {{{1
if [[ $1 == "--in-X" ]]; then
    _continue_in_X
else
    _run "$@"
fi
# }}}1

# vim: foldmethod=marker
