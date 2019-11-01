ARG zabbix_web_tag
FROM zabbix/zabbix-web-nginx-pgsql:$zabbix_web_tag

COPY realip.conf /etc/nginx/
RUN sed -i'' -e '/include \/etc\/nginx\/conf.d\/\*.conf;/a\    include /etc/nginx/realip.conf;' /etc/nginx/nginx.conf
