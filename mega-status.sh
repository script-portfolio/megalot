#!/bin/bash

set -u

APP=$0
# http://stackoverflow.com/questions/1197690/how-can-i-derefence-symbolic-links-in-bash
REAL_PATH=$(readlink -f "$APP" )
HERE_PATH=$(dirname "${REAL_PATH}" )
STATUSFILE="$HERE_PATH/status.file"

((0)) && {
    LAST_EVENT_LINE=$(cat -n  "${HERE_PATH}/file.log" | grep Started\. | tail -1 | awk '{print $1}')
    tail -n +$((LAST_EVENT_LINE)) "${HERE_PATH}/file.log"
}

[ -f "${STATUSFILE}" ] && \
cat $STATUSFILE
