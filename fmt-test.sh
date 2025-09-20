#!/usr/bin/env sh
# Why implement by shell script is because not so complex processes now.
# However, if this progress to complex process, it should to replace with some other langurges.
set -eu
BASEDIR=$(pwd)
cd "${BASEDIR}/${1}"
terraform fmt -recursive
terraform validate
if test -f ".tflint.hcl"; then
    tflint --init
    tflint --recursive
fi
