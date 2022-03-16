#!/bin/bash -x

set -euo pipefail

NEW_USER_ID=${USER_ID}
NEW_GROUP_ID=${GROUP_ID:-$NEW_USER_ID}

echo "Starting with habapp user id: $NEW_USER_ID and group id: $NEW_GROUP_ID"
if ! id -u habapp >/dev/null 2>&1; then
  if [ -z "$(getent group $NEW_GROUP_ID)" ]; then
    echo "Create group habapp with id ${NEW_GROUP_ID}"
    groupadd -g $NEW_GROUP_ID habapp
  else
    group_name=$(getent group $NEW_GROUP_ID | cut -d: -f1)
    echo "Rename group $group_name to habapp"
    groupmod --new-name habapp $group_name
  fi
  echo "Create user habapp with id ${NEW_USER_ID}"
  adduser -u $NEW_USER_ID --disabled-password --gecos '' --home "${HABAPP_HOME}" --gid ${NEW_GROUP_ID} habapp
fi

mkdir -p "${HABAPP_HOME}/config/log"

chown -R habapp:habapp "${HABAPP_HOME}/config"
sync

if ! pgrep -x "dbus-daemon" > /dev/null 
then
    echo "dbus-daemon not running"
    service dbus start
else
    echo "dbus-daemon already running"
fi

if ! pgrep -x "signal-cli" > /dev/null
then   
  echo "signal-cli daemon not running"
  gosu habapp ${SIGNAL_DIR}/bin/signal-cli --config ${HABAPP_HOME}/signal -a ${SIGNAL_NUMBER} daemon --system > ${HABAPP_HOME}/config/log/signal.log 2>&1 &
else
  echo "signal-cli daemon already running"
fi

exec gosu habapp "$@"
