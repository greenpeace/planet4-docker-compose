#!/usr/bin/env bash
set -eax

pushd persistence/app/public/wp-content/themes/planet4-master-theme
yarn
gulp watch&
popd

pushd persistence/app/public/wp-content/plugins/planet4-plugin-blocks
yarn
gulp watch&
popd

cat
