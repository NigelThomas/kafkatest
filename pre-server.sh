# Install the repro case
#
# Assumes we are running in a docker container (eg sqlstream/minimal:release) as root (no need for sudo)

. /etc/sqlstream/environment

cat >> /var/log/sqlstream/Trace.properties <<!END
com.sqlstream.aspen.namespace.kafka.level=CONFIG
!END

