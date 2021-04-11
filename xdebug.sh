#!/usr/bin/env bash

if [[ $EUID != 0 ]]; then
  >&2 echo -e '\e[91mThis command should be run as root.\e[0m'
  exit 1
fi

# This value is set in cmd.sh
SERVER='%SERVER%'

if [[ $1 == 'on' ]]; then
  if [[ $SERVER == 'apache' ]]; then
    # Apache fails with "signal Segmentation fault" when reload is used.
    phpenmod xdebug && service apache2 restart
  else
    phpenmod -s fpm xdebug && phpenmod -s cli xdebug && service php%PHP_VERSION%-fpm reload
  fi
elif [[ $1 == 'off' ]]; then
  if [[ $SERVER == 'apache' ]]; then
    phpdismod xdebug && service apache2 restart
  else
    phpdismod -s fpm xdebug && phpdismod -s cli xdebug && service php%PHP_VERSION%-fpm reload
  fi
else
  >&2 echo 'Usage:' $(basename -- "$0") '[on|off]';
  exit 1
fi
