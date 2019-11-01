#!/usr/bin/env bash
# Create database for Zabbix
# Envirinment variables ZABBIX_DB, ZABBIX_DBUSER, ZABBIX_DBPASSWORD or their _FILE variants are used as parameters
# This script will be executed only if Postgres data direcory is empty i.e. on first container run

set -e

# Borrowed from https://github.com/zabbix/zabbix-docker/blob/4.4/web-nginx-pgsql/ubuntu/docker-entrypoint.sh
# usage: file_env VAR [DEFAULT]
# as example: file_env 'MYSQL_PASSWORD' 'zabbix'
#    (will allow for "$MYSQL_PASSWORD_FILE" to fill in the value of "$MYSQL_PASSWORD" from a file)
# unsets the VAR_FILE afterwards and just leaving VAR
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local defaultValue="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo >&2 "**** Both variables $var and $fileVar are set (but are exclusive)"
        exit 1
    fi

    local val="$defaultValue"

    if [ "${!var:-}" ]; then
        val="${!var}"
        echo "** Using ${var} variable from ENV"
    elif [ "${!fileVar:-}" ]; then
        if [ ! -f "${!fileVar}" ]; then
            echo >&2 "**** Secret file \"${!fileVar}\" is not found"
            exit 1
        fi
        val="$(< "${!fileVar}")"
        echo "** Using ${var} variable from secret file"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

file_env ZABBIX_DB zabbix
file_env ZABBIX_DBUSER zabbix
file_env ZABBIX_DBPASSWORD zabbix

file_env ZABBIX_RO_DBUSER grafana
file_env ZABBIX_RO_DBPASSWORD grafana

echo "** Creating Zabbix DB with parameters:
   DB Name: ${ZABBIX_DB}
   DB User: ${ZABBIX_DBUSER}
   DB Password: ${ZABBIX_DBPASSWORD}"

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOSQL
    CREATE USER ${ZABBIX_DBUSER} WITH PASSWORD '${ZABBIX_DBPASSWORD}';
    CREATE DATABASE ${ZABBIX_DB} WITH OWNER ${ZABBIX_DBUSER} ENCODING='UTF8';
    GRANT ALL PRIVILEGES ON DATABASE ${ZABBIX_DB} TO ${ZABBIX_DBUSER};
EOSQL

echo "** Creating Read-Only DB User with parameters:
   Read-Only User: ${ZABBIX_RO_DBUSER}
   Read-Only Password: ${ZABBIX_RO_DBPASSWORD}"

# 'FOR ROLE ${ZABBIX_DBUSER}' is crucial because tables will be created as zabbix user, but we are working
# as 'postgres' user and DEFAULT PRIVILEGES won't trigger on any operation as zabbix user
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${ZABBIX_DB}" <<-EOSQL
    CREATE USER ${ZABBIX_RO_DBUSER} WITH PASSWORD '${ZABBIX_RO_DBPASSWORD}';
    GRANT CONNECT ON DATABASE ${ZABBIX_DB} TO ${ZABBIX_RO_DBUSER};
    GRANT USAGE ON SCHEMA public TO ${ZABBIX_RO_DBUSER};
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO ${ZABBIX_RO_DBUSER};
    GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO ${ZABBIX_RO_DBUSER};
    ALTER DEFAULT PRIVILEGES FOR ROLE ${ZABBIX_DBUSER} IN SCHEMA public GRANT SELECT ON TABLES TO ${ZABBIX_RO_DBUSER};
EOSQL
