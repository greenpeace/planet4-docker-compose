#!/usr/bin/env bash
set -eao pipefail

[ -x "$(command -v yarn)" ] || { >&2 echo "yarn is required but not installed, exiting."; exit 1; }
[ -x "$(command -v gulp)" ] || { >&2 echo "gulp is requited but not installed, exiting."; exit 1; }

pushd persistence/app/public/wp-content/themes/planet4-master-theme
yarn
gulp watch&
popd

pushd persistence/app/public/wp-content/plugins/planet4-plugin-blocks
yarn
gulp watch&
popd

cat
