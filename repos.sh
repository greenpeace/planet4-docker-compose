#!/usr/bin/env bash
set -ea

if [[ $GIT_PROTO = "ssh" ]]
then
  GIT_DOMAIN="git@github.com:"
else
  GIT_DOMAIN="https://github.com/"
fi

git clone --recurse-submodules ${GIT_DOMAIN}greenpeace/planet4-master-theme.git persistence/app/public/wp-content/themes/planet4-master-theme
pushd persistence/app/public/wp-content/themes/planet4-master-theme
npm install
npm run build
composer install
popd

for plugin in gutenberg-blocks gutenberg-engagingnetworks
do
  git clone --recurse-submodules ${GIT_DOMAIN}greenpeace/planet4-plugin-${plugin}.git persistence/app/public/wp-content/plugins/planet4-plugin-${plugin}
  pushd persistence/app/public/wp-content/plugins/planet4-plugin-${plugin}
  npm install
  npm run build
  composer install
  popd
done
