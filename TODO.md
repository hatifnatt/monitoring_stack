# TODO
Zabbix API:
  - Устанавливать пароль для Zabbix пользователя Admin
  - Создать группу Read Only и в ней пользователя для API доступа
  - Добавлять в Zabbix хост Dockerhost
  - Редактировать хост Zabbix server до правильного состояния через API, т.е. удалять шаблон Zabbix Agent.

Прочее:
  - Запускать все же node_exporter в контейнер? Или не стоит... Это определенно упростит развертывание на докер-хосте, но в любом случае нужно будет подключать еще и внешние хосты.
