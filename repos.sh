#!/usr/bin/env bash
set -eax

if [[ $GIT_PROTO = "ssh" ]]
then
  GIT_DOMAIN="git@github.com:"
else
  GIT_DOMAIN="https://github.com/"
fi

LOCAL_P4MT_PATH=${LOCAL_P4MT_PATH:-./persistence/app/public/wp-content/themes/planet4-master-theme}
LOCAL_P4GBKS_PATH=${LOCAL_P4GBKS_PATH:-./persistence/app/public/wp-content/plugins/planet4-plugin-gutenberg-blocks}
LOCAL_P4GEN_PATH=${LOCAL_P4GEN_PATH:-./persistence/app/public/wp-content/plugins/planet4-plugin-gutenberg-engagingnetworks}

echo "Cloning main theme and plugins..."

if [ ! -d "${LOCAL_P4MT_PATH}" ]
then
  git clone --recurse-submodules ${GIT_DOMAIN}greenpeace/planet4-master-theme.git "${LOCAL_P4MT_PATH}"
else
  git submodule update --init
fi

if [ ! -d "${LOCAL_P4GBKS_PATH}" ]
then
  git clone --recurse-submodules ${GIT_DOMAIN}greenpeace/planet4-plugin-gutenberg-blocks.git "${LOCAL_P4GBKS_PATH}"
else
  git submodule update --init
fi

if [ ! -d "${LOCAL_P4GEN_PATH}" ]
then
  git clone --recurse-submodules ${GIT_DOMAIN}greenpeace/planet4-plugin-gutenberg-engagingnetworks.git "${LOCAL_P4GEN_PATH}"
else
  git submodule update --init
fi

echo "Done."