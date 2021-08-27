#!/usr/bin/env bash

# Return orignal mysql directory if the mounted one is empty.
if [ ! "$(ls -A "/var/lib/mysql")" ]; then
  cp -R /var/lib/mysql_default/* /var/lib/mysql
  chown -R mysql:mysql /var/lib/mysql
fi

# Change document root owner.
if [ ! "$(ls -A "/var/www")" ]; then
  chown $HOST_USER_NAME:$HOST_USER_NAME /var/www
fi

nohup mailhog &

sed -i "s/%SERVER%/$SERVER/g" /usr/local/bin/xdebug

if [[ $SERVER == 'apache' ]]; then
  echo 'Starting apache...'
  service apache2 start
  LOG=/var/log/nginx/access.log
else
  echo 'Starting nginx...'
  service nginx start
  echo "Starting php$PHP_VERSION-fpm..."
  service php$PHP_VERSION-fpm start
  LOG=/var/log/apache2/access.log
fi

xdebug off

service mariadb start

service ssh start

tail -f $LOG
