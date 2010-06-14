#!/bin/zsh

exp () {
    echo "*** Setting envvar '$1' to '$2'"
    export $1=$2
}

exc () {
    if [[ $1 == "-f" ]]; then
        fork=1
        msg=" (forking)"
        shift
    fi

    echo "*** Executing${msg}:"
    echo $@
    
    sleep 3

    if [[ -n $fork ]]; then
        exec $@ &!
    else
        eval $@
    fi
}

if [[ $1 == "-x" ]]; then
    local prefix=$2
    local gpath=$3
    local args=$5
    local size=$4

    # load settings
    nvidia-settings -l

    # set display size
    [[ -n $size ]] && xrandr -s $size

    # exporting variables
    exp WINEPREFIX `eval echo $prefix`
    exp WINEDEBUG "-all"
    exp DISPLAY ":1"

    exc wine start $gpath $args
    exc wineserver -w
else
    local game=$1

    echo "*** Launching '$game'"

    local prefix="~/.wine/"
    local gpath size args
    local x11args

    steam () {
        prefix="~/.steam/"
        gpath="c:/Programme/steam/steam.exe"
        size="1280x1024"

        [[ $# > 0 ]] && args=$@
    }

    typeset -A games
    games[bg2]='gpath=c:/spiele/bg2/baldur.exe; size=1024x768'
    games[fallout]='prefix=~/.fallout/; gpath=c:/spiele/fallout/falloutw.exe; size=800x600; x11args="-depth 16"'
    games[steam]='steam'

    if [[ -z $games[$game] ]]; then
        echo "*** Game '$game' not found"
        echo "Games are:"
        for k in ${(ko)games}; do
            echo "\t> $k"
        done
        exit 1
    else
        eval $games[$game]
    fi

    exc -f startx $0 -x $prefix $gpath $size "$args" -- :1 -ac -br -quiet ${=x11args}
fi
