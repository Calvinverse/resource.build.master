#!/bin/sh

# From here: https://jenkins.io/blog/2016/11/21/gc-tuning/
JAVA_SERVER_ARGS="-server -XX:+AlwaysPreTouch"
JAVA_G1_GC_ARGS="-XX:+UseG1GC -XX:+ExplicitGCInvokesConcurrent -XX:+ParallelRefProcEnabled -XX:+UseStringDeduplication -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:+UnlockDiagnosticVMOptions -XX:G1SummarizeRSetStatsPeriod=1"
JAVA_HEAP_ARGS="-Xms512m -Xmx1024m"
JAVA_AWT_ARGS="-Djava.awt.headless=true"

# `/sbin/setuser memcache` runs the given command as the user `memcache`.
# If you omit that part, the command will be run as root.
exec /sbin/setuser jenkins java $JAVA_SERVER_ARGS $JAVA_G1_GC_ARGS $JAVA_HEAP_ARGS $JAVA_AWT_ARGS -jar /etc/jenkins/jenkins.war --httpPort=8080 --prefix=/jenkins 2>&1 | logger
