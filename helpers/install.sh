#!/usr/bin/env bash

# Install systemd service files
# get script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

cd "$DIR/systemd"
# create directory structure
find -type d -exec install -vd -o root -g root "{}" "/etc/systemd/system/{}" \;
# copy files
find -type f -exec install -vC -o root -g root -m 644 "{}" "/etc/systemd/system/{}" \;

systemctl daemon-reload
