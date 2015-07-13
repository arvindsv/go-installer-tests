#!/bin/bash

set -e
set -o pipefail

if [ "$#" -ne 1 ]; then echo "Usage: $0 go-component-package-name" >&2 && exit 1; fi
package_name="$1"
go_install_response_file="$(dirname $0)/go-install.response"

pkgrm -n -a "${go_install_response_file}" "$package_name"
