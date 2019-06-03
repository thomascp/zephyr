#!/bin/bash
set -e
set -u

ROOT_PATH="`dirname \"\`realpath "$0"\`\"`"

. "${ROOT_PATH}/common.sh"

set +e
STTY_CONFIG=`stty -g 2>/dev/null`
python -u "`get_path "$ROOT_PATH/run_tests.py"`" --exclude skip-$DETECTED_OS --robot-framework-remote-server-full-directory=/opt/renode/bin -r . "$@"
RESULT_CODE=$?
set -e
if [ -n "${STTY_CONFIG:-}" ]
then
    stty "$STTY_CONFIG"
fi
exit $RESULT_CODE
