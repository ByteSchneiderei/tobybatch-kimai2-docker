#!/bin/bash -x

KIMAI=$(cat /opt/kimai/version.txt)
echo $KIMAI


function config() {
  # set mem limits and copy in custom logger config
  if [ -z "$memory_limit" ]; then
    memory_limit=256
  fi


  # Parse sql connection data
  if [ ! -z "$DATABASE_URL" ]; then
    DB_TYPE=$(awk -F '[/:@]' '{print $1}' <<< "$DATABASE_URL")
    DB_USER=$(awk -F '[/:@]' '{print $4}' <<< "$DATABASE_URL")
    DB_PASS=$(awk -F '[/:@]' '{print $5}' <<< "$DATABASE_URL")
    DB_HOST=$(awk -F '[/:@]' '{print $6}' <<< "$DATABASE_URL")
    DB_PORT=$(awk -F '[/:@]' '{print $7}' <<< "$DATABASE_URL")
    DB_BASE=$(awk -F '[/?]' '{print $4}' <<< "$DATABASE_URL")
  else
    DB_TYPE=${DB_TYPE:mysql}
    if [ "$DB_TYPE" == "mysql" ]; then
      export DATABASE_URL="${DB_TYPE}://${DB_USER:=kimai}:${DB_PASS:=kimai}@${DB_HOST:=sqldb}:${DB_PORT:=3306}/${DB_BASE:=kimai}"
    else
      echo "Unknown database type, cannot proceed. Only 'mysql' is supported, received: [$DB_TYPE]"
      exit 1
    fi
  fi

  re='^[0-9]+$'
  if ! [[ $DB_PORT =~ $re ]] ; then
     DB_PORT=3306
  fi

  echo "Wait for MySQL DB connection ..."
  until php /dbtest.php $DB_HOST $DB_BASE $DB_PORT $DB_USER $DB_PASS; do
    echo Checking DB: $?
    sleep 3
  done
  echo "Connection established"
}

function handleStartup() {
  set -x
  # set mem limits and copy in custom logger config
  if [ "${APP_ENV}" == "prod" ]; then
    sed -i "s/128M/${memory_limit}M/g" /usr/local/etc/php/php.ini
    if [ "${KIMAI:0:1}" -lt "2" ]; then
      cp /assets/monolog-prod.yaml /opt/kimai/config/packages/prod/monolog.yaml
    else
      cp /assets/monolog.yaml /opt/kimai/config/packages/monolog.yaml
    fi
  else
    sed -i "s/128M/${memory_limit}M/g" /usr/local/etc/php/php.ini
    if [ "${KIMAI:0:1}" -lt "2" ]; then
      cp /assets/monolog-dev.yaml /opt/kimai/config/packages/dev/monolog.yaml
    else
      cp /assets/monolog.yaml /opt/kimai/config/packages/monolog.yaml
    fi
  fi
  set +x

  tar -zx -C /opt/kimai -f /var/tmp/public.tgz

  chown -R www-data:www-data /opt/kimai
}

config
handleStartup
/service.sh
exit
