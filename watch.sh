#!/usr/bin/env bash
set -eao pipefail

[ -x "$(command -v npm)" ] || { >&2 echo "npm is required but not installed, exiting."; exit 1; }
[ -x "$(command -v gulp)" ] || { >&2 echo "gulp-cli is requited but not installed, exiting."; exit 1; }

pushd persistence/app/public/wp-content/themes/planet4-master-theme
npm install
gulp watch&
popd

pushd persistence/app/public/wp-content/plugins/planet4-plugin-blocks
npm install
gulp watch&
popd

cat
