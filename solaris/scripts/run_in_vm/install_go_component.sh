#!/bin/bash

set -e
set -o pipefail
source /etc/profile

# Wait for service state to change.
function wait_till_state_changes_from_or_timeout() {
  local service="$1"
  local state_which_it_should_not_be_in="$2"
  local max_timeout="$3"

  for each in {1..$max_timeout}; do
    if [ "$(svcs -Ho state "$service" | sed -e 's/[^a-zA-Z]//g')" != "$state_which_it_should_not_be_in" ]; then
        break
    fi
    sleep 1
  done
  echo "Current state of $service: $(svcs -Ho state "$service")"
}


if [ "$#" -ne 2 ]; then echo "Usage: $0 path-to-installer-package agent|server" >&2 && exit 1; fi
if [ ! -f "$1" ]; then echo "Installer package does not exist: $1" >&2 && exit 2; fi
if [ "$2" != "agent" -a "$2" != "server" ]; then echo "Usage: $0 path-to-installer-package agent|server" >&2 && exit 3; fi
installer_file="$1"
component="$2"

service="go/$component"
go_install_response_file="$(dirname $0)/go-install.response"
installer_filename="$(basename "$installer_file")"

cd /tmp
/bin/cp -f "$installer_file" .

gzip -df "$installer_filename"
pkgadd -a "${go_install_response_file}" -d "${installer_filename%.gz}" all


# Setup JAVA_HOME properly.
wait_till_state_changes_from_or_timeout "$service" "offline" 5

echo "Setting up environment variables properly"
sed -e 's/GO_SERVER=127.0.0.1/GO_SERVER=go-server/' /usr/share/go-$component/default.cruise-$component >/etc/default/go-$component
echo "export JAVA_HOME=\"$JAVA_HOME\"" >>/etc/default/go-$component

echo "Removing maintenance mode flag from $service"
svcadm clear "$service" || echo "Did not need to clear mode, since $service was not in maintenance mode"

echo "Restarting $service"
svcadm restart "$service"

wait_till_state_changes_from_or_timeout "$service" "maintenance" 5
wait_till_state_changes_from_or_timeout "$service" "offline" 5
