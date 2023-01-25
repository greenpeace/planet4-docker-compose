#!/usr/bin/env bash
set -ea

BASE_BRANCH="upgrade-node"

if [[ "${GIT_PROTO}" = "ssh" ]]
then
  GIT_DOMAIN="git@github.com:"
else
  GIT_DOMAIN="https://github.com/"
fi

git clone --branch ${BASE_BRANCH} ${GIT_DOMAIN}greenpeace/planet4-master-theme.git persistence/app/public/wp-content/themes/planet4-master-theme

git clone --branch ${BASE_BRANCH} --recurse-submodules --shallow-submodules ${GIT_DOMAIN}greenpeace/planet4-plugin-gutenberg-blocks.git persistence/app/public/wp-content/plugins/planet4-plugin-gutenberg-blocks
