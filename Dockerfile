FROM fedora:21
MAINTAINER Pantheon Systems

RUN yum -y update && yum clean all
RUN yum -y install mariadb-server pwgen psmisc net-tools hostname && \
    yum clean all

ADD scripts /scripts
RUN chmod 755 /scripts/*

VOLUME ["/var/lib/mysql", "/var/log/mysql"]
EXPOSE 3306

CMD ["/bin/bash", "/scripts/start.sh"]
