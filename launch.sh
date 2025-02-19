#!/bin/bash

# Switch to workdir
cd "${STEAMAPPDIR}"

xvfbpid=""
ckpid=""

function kill_corekeeperserver {
        if [[ ! -z "$ckpid" ]]; then
                kill $ckpid
        fi
        sleep 1
        if [[ ! -z "$xvfbpid" ]]; then
                kill $xvfbpid
        fi
}

trap kill_corekeeperserver EXIT

if ! (dpkg -l xvfb >/dev/null) ; then
    echo "Installing xvfb dependency..."
    sleep 1
    sudo apt-get update -yy && sudo apt-get install xvfb -yy
fi

set -m

rm -f /tmp/.X99-lock

Xvfb :99 -screen 0 1x1x24 -nolisten tcp &
export DISPLAY=:99
xvfbpid=$!

# Wait for xvfb ready.
# Thanks to https://hg.mozilla.org/mozilla-central/file/922e64883a5b4ebf6f2345dfb85f04b487a0e714/testing/docker/desktop-build/bin/build.sh
retry_count=0
max_retries=2
xvfb_test=0
until [ $retry_count -gt $max_retries ]; do
    xvinfo
    xvfb_test=$?
    if [ $xvfb_test != 255 ]; then
        retry_count=$(($max_retries + 1))
    else
        retry_count=$(($retry_count + 1))
        echo "Failed to start Xvfb, retry: $retry_count"
        sleep 2
    fi done
  if [ $xvfb_test == 255 ]; then exit 255; fi

rm -f GameID.txt

chmod +x ./CoreKeeperServer

DISPLAY=:99 LD_LIBRARY_PATH="$LD_LIBRARY_PATH:../Steamworks SDK Redist/linux64/" ./CoreKeeperServer -batchmode -logfile -world "${WORLD_INDEX}" -worldname "${WORLD_NAME}" -worldseed "${WORLD_SEED}" -gameid "${GAME_ID}" -datapath "${STEAMAPPDATADIR}" -maxplayers "${MAX_PLAYERS}" -logfile CoreKeeperServerLog.txt &

ckpid=$!

echo "Started server process with pid $ckpid"

while [ ! -f GameID.txt ]; do
        sleep 0.1
done

gameid=$(cat GameID.txt)
echo "Game ID: ${gameid}"

if [ -z "$DISCORD" ]; then
	DISCORD=0
fi

if [ $DISCORD -eq 1 ]; then
    if [ -z "$DISCORD_HOOK" ]; then
	echo "Please set DISCORD_WEBHOOK url."
        else
        curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST --data "{\"content\": \"${gameid}\"}" "${DISCORD_HOOK}"
    fi
fi

wait $ckpid
ckpid=""
