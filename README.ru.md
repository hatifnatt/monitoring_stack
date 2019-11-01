# Набор контейнеров для мониторинга
  - [Zabbix](https://www.zabbix.com/) Server + Zabbix Web + [PostgreSQL](https://www.postgresql.org/)
  - [Prometheus](https://prometheus.io/) + [Grafana](http://grafana.org/) + [cAdvisor](https://github.com/google/cadvisor)
  - [nginx-proxy](https://github.com/jwilder/nginx-proxy) + [letsencrypt-nginx-proxy-companion](https://github.com/JrCs/docker-letsencrypt-nginx-proxy-companion)

## Установка
Склонируйте репозиторий в каталог `/opt/monitoring`, задайте пароли и выполните другие настройки описанные ниже. Запустите контейнеры в нужном [порядке](#Порядок%20запуска) с помощью `docker-compose` или `systemd` (предпочтительно).
```
cd /opt
git clone https://github.com/hatifnatt/monitoring_stack monitoring
cd /opt/monitoring
echo "zabbix_pass"> zabbix/zabbix.pass
echo "postgres_pass"> zabbix/postgres.pass
echo "ZABBIX_RO_DBPASSWORD=your_readonly_pass" >> zabbix/.env
echo "ZABBIX_RO_DBPASSWORD=your_readonly_pass" >> promgraf/.env
```

Запуск с помощью `docker-compose`
```
docker-compose -f nginx-proxy/docker-compose.yml up -d
docker-compose -f zabbix/docker-compose.yml up -d
docker-compose -f promgraf/docker-compose.yml up -d
docker-compose -f exporters/docker-compose.yml up -d
```

Запуск с помощью `systemd` - это предпочтительный вариант, т.к. гарантирует правильный порядок запуска сервисов при загрузке сисемы.
```
cd /opt/monitoring/helpers
# install systemd service
./install.sh
# if you are not root use su or sudo
su - -c ./install.sh
sudo ./install.sh
# start services
systemctl enable --now monitoring@proxy
systemctl enable --now monitoring@zabbix
systemctl enable --now monitoring@promgraf
systemctl enable --now monitoring@exportrs
```

### Установка паролей
Для установки паролей необходимо создать файлы содержащие пароли, без данных файлов запуск контейнеров завершится с ошибкой.
  - Пароль суперпользователь `postgres`: `zabbix/postgres.pass`
  - Пароль пользователя для БД Zabbix (имя пользователя по умолчанию `zabbix`): `zabbix/zabbix.pass`
  - Пароль администратора Grafana (имя пользователя по умолчанию `admin`): `promgraf/grafana.pass`

Пользователь и пароль для read-only доступа в БД Zabbix, задаются через переменные окружения или в файлах `zabbix/.env`, `promgraf/.env`.
```
ZABBIX_RO_DBUSER=grafana
ZABBIX_RO_DBPASSWORD=grafana
```

__ВНИМАНИЕ!__ пароли для пользователей БД postgres, zabbix, grafana в БД PostgreSQL задаются только при первом первом запуске контейнера `postgres` (или когда контейнер стартует с пустым каталог данных `postgres/data`) последующее изменение файлов с паролями и переменных окружения не даст никакого эффекта, действующие пароли в БД PostgreSQL не будут изменены. Для изменения паролей можно воспользоваться веб интерфейсом, который предоставляет контейнер `adminer`. По умолчанию он доступен по адресу `http://127.0.0.1:8080` для удаленного доступа можно пробросить порт с помощью `ssh`. Так же это можно сделать используя `psql` в контейнере `postgres`:
```
docker exec -ti postgres /usr/bin/psql -U postgres

ALTER ROLE zabbix WITH PASSWORD 'changeme';
ALTER ROLE grafana WITH PASSWORD 'another_pass';
```

#### http basic auth
Контейнер nginx-proxy [позволяет](https://github.com/jwilder/nginx-proxy#basic-authentication-support) включать _http basic auth_ для проксируемых доменов. Для этого нужно создать файлы `htpasswd` с именами вида `proxy/nginx/htpasswd/%VHOST%`, где `%VHOST%` имя проксируемого домена, например `your.domain.tld`. Создаются данные файлы с помощью утилиты [htpasswd](http://httpd.apache.org/docs/2.2/programs/htpasswd.html) из пакета `apache2-utils`. 

### Установка доменов для внешнего доступа
Zabbix Web, Grafana и Prometheus могут быть доступны через интернет по внешним именам, а так же для них могут быть автоматически выпущены сертификаты Let's Encrypt. Предварительно нужно создать DNS записи которые будут указывать на нужный сервер. Затем необходимо создать `.env` файлы, примеры ниже.

#### Zabbix Web
`zabbix/.env`
```
ZABBIX_VHOST=zabbix.domain.tld
# Раскоментируйте строку с ZABBIX_VHOST_LE чтоб выпустить сертификат для этого домена. 
# ZABBIX_VHOST_LE=zabbix.domain.tld
```

#### Grafana / Prometheus
`promgraf/.env`
```
PROMETHEUS_SCHEME=http
PROMETHEUS_VHOST=prom.domain.tld
# PROMETHEUS_VHOST_LE=prom.domain.tld

GRAFANA_SCHEME=http
GRAFANA_VHOST=grafana.domain.tld
# GRAFANA_VHOST_LE=grafana.domain.tld
```

### Выбор версии (тега) для контейнеров
Для выбора версии, отличной от заданной в `docker-compose.yml` добавьте в `.env` файл соответствующие переменные, например:

`zabbix/.env`
```
POSTGRES_TAG=12
ZABBIX_SEVER_TAG=ubuntu-4.4.1
```
`proxy/.env`
```
NGINX_PROXY_TAG=latest
LE_COMPANION_TAG=v1.12
```
Имена переменных можно увидеть в соответствующих `docker-compose.yml` файлах.

### Переопределение параметров
При необходимости, переменые заданные в файлах `postgres.env`, `zabbix.env`, `grafana.env` и т.п. можно переопределить, для этого нужно создать свой файл с параметрами, например `postgres.custom.env` переопределить там нужные параметры и затем отредактировать `docker-compose.yml`
```
    env_file:
      - ./postgres.env
      - ./postgres.custom.env
```
В результате переменные примут те значения, что заданы в `postgres.custom.env`. Подробнее про это [в документации](https://docs.docker.com/compose/compose-file/#env_file).
Хотя гораздо проще просто отредактировать нужные `.env ` файлы возможно вы хотите минимальных изменений по сравнению с "апстримомо", особенно если развертывание происходило из гита.

## Порядок запуска
Запуск контейнеров необходимо выполнять в определенном порядке.
  - proxy
  - zabbix
  - promgraf
  - exporters

## Настройка proxy
В файле `proxy/le-companion.env` необходимо задать корректный e-mail для получения уведомлений от Let's  Encrypt в случае если какой-то SSL сертификат скоро истечет. Без файла `proxy/le-companion.env` стек `proxy` не запустится.
```
DEFAULT_EMAIL=yourmail@example.tld
```

## Настройка Zabbix
По умолчанию веб интерфейс Zabbix доступен по адресу http://127.0.0.1:8081/ или по адресу, который вы указали в параметре `ZABBIX_VHOST` в `.env` файле, (eстественно должен быть корректно настроен DNS). Логин и пароль по умолчанию для Zabbix - __Admin/zabbix__ эти же данные используются в Grafana для доступа к Zabbix API, пароль администратора однозначно нужно изменить, после этого так же требуется обновиться настройки в Grafana, об этом далее. Я рекомендую создать пользователя с правами только для чтения для всех хостов и уже его использовать для доступа в Zabbix API из Grafana, инструкция как это сделать выходит за рамки данной документации.

## Настройка Grafana
По умолчанию веб интерфейс Grafana доступен по адресу http://127.0.0.1:3000/ или по адресу, который вы указали в параметре `GRAFANA_VHOST` в `.env` файле. Логин по умолчанию __admin__ пароль, тот что вы задали в файле `promgraf/grafana.pass`.

### Zabbix datasource в Grafana
Для получения данных из Zabbix используется 2 варианта доступа, через Zabbix API и прямые запросы в БД, в данном сучае в PostgreSQL. Эти источники данных требуют аутентификации, как упоминалось выше, рекомендуется создать отдельного пользователя с правами только на чтение для доступа в Zabbix API (по умолчанию используется пользователь Admin, который обладает правами суперадминистратора).

Логины и пароли задаются через переменные окружения или в файле `promgraf/.env`

```
ZABBIX_API_USER=Admin
ZABBIX_API_PASS=zabbix

ZABBIX_RO_DBUSER=grafana
# здесь должно быть то же значение что и в аналогичной переменной в файле zabbix/.env
ZABBIX_RO_DBPASSWORD=grafana
```

### Grafana dashboards and datasources provisioning
В Grafana версии 5+ возможна инициализация дашбордов и источников данных путем размешения файлов в специальных каталогах, подоробнее в [документации.](https://grafana.com/docs/administration/provisioning/)
  - Каталога для дашбордов (json файлы) `promgraf/grafana/dashboards`
  - Каталог для источников данных (yaml файлы) `promgraf/grafana/etc/provisioning/datasources`

## Ссылки на документацию и страницы проектов
### Docker Hub
  - Zabbix Stack
    - [zabbix/zabbix-server-pgsql](https://hub.docker.com/r/zabbix/zabbix-server-pgsql)
    - [zabbix/zabbix-web-nginx-pgsql](https://hub.docker.com/r/zabbix/zabbix-web-nginx-pgsql)
    - [postgres](https://hub.docker.com/_/postgres/)
  - Modern Stack
    - [prom/prometheus](https://hub.docker.com/r/prom/prometheus)
    - [prom/node-exporter](https://hub.docker.com/r/prom/node-exporter)
    - [grafana/grafana](https://hub.docker.com/r/grafana/grafana)
    - [google/cadvisor](https://hub.docker.com/r/google/cadvisor)
  - Proxy Stack
    - [jwilder/nginx-proxy](https://hub.docker.com/r/jwilder/nginx-proxy)
    - [jrcs/letsencrypt-nginx-proxy-companion](https://hub.docker.com/r/jrcs/letsencrypt-nginx-proxy-companion)
  - Exporters
    - [nginx/nginx-prometheus-exporter](https://hub.docker.com/r/nginx/nginx-prometheus-exporter)
    - [prom/node-exporter](https://hub.docker.com/r/prom/node-exporter)

### GitHub или другие страницы проектов
  - [Zabbix Docker](https://github.com/zabbix/zabbix-docker)
  - [Grafana](https://github.com/grafana/grafana/blob/master/packaging/docker/)
    - [Installing using Docker](https://grafana.com/docs/installation/docker/)
  - [cAdvisor](https://github.com/google/cadvisor)
    - [Docs](https://github.com/google/cadvisor/tree/master/docs)
  - [nginx-prometheus-exporter](https://github.com/nginxinc/nginx-prometheus-exporter/)
  - [apache_exporter](https://github.com/Lusitaniae/apache_exporter)
  - [prometheus/node_exporter](https://github.com/prometheus/node_exporter)

### Источники идей или "по мотивам"
  - [stefanprodan/dockprom](https://github.com/stefanprodan/dockprom)
