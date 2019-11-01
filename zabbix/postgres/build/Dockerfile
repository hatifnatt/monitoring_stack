ARG postgres_tag
FROM postgres:$postgres_tag
# Generate additional locale, work only in ubuntu base image
RUN localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8
