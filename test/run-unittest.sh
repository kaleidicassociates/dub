#!/bin/bash

set -v

function log() {
    echo -e "\033[0;33m[INFO] "$@"\033[0m"
}

function logError() {
    echo -e 1>&2 "\033[0;31m"$@"\033[0m"
    any_errors=1
}

function die() {
    logError "$@"
    exit 1
}

export -f log
export -f die

if [ -z ${DUB} ]; then
    die 'Error: Variable $DUB must be defined to run the tests.'
fi

if [ -z ${DC} ]; then
    log '$DC not defined, assuming dmd...'
    DC=dmd
fi

CURR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

for script in $(ls $CURR_DIR/*.sh); do
    if [ "$script" = "$CURR_DIR/run-unittest.sh" ]; then continue; fi
    if [ -e $script.min_frontend ] && [ ! -z "$FRONTEND" -a "$FRONTEND" \< $(cat $script.min_frontend) ]; then continue; fi
    log "Running $script..."
    DUB=$DUB DC=$DC CURR_DIR="$CURR_DIR" $script || logError "Script failure."
done

for pack in $(ls -d $CURR_DIR/*/); do
    if [ -e $pack/.min_frontend ] && [ ! -z "$FRONTEND" -a "$FRONTEND" \< $(cat $pack/.min_frontend) ]; then continue; fi
    # First we build the packages
    if [ ! -e $pack/.no_build ]; then # For sourceLibrary
        if [ -e $pack/.fail_build ]; then
            log "Building $pack, expected failure..."
            $DUB build --force --root=$pack --compiler=$DC 2>/dev/null && logError "Error: Failure expected, but build passed."
        else
            log "Building $pack..."
            $DUB build --force --root=$pack --compiler=$DC || logError "Build failure."
        fi
    fi

    # We run the ones that are supposed to be runned
    if [ ! -e $pack/.no_build ] && [ ! -e $pack/.no_run ]; then
        log "Running $pack..."
        $DUB run --force --root=$pack --compiler=$DC || logError "Run failure."
    fi

    # Finally, the unittest part
    if [ ! -e $pack/.no_build ] && [ ! -e $pack/.no_test ]; then
        log "Testing $pack..."
        $DUB test --force --root=$pack --compiler=$DC || logError "Test failure."
    fi
done

exit $any_errors
