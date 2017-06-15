#!/bin/sh

# From here: https://jenkins.io/blog/2016/11/21/gc-tuning/
JAVA_SERVER_ARGS="-server -XX:+AlwaysPreTouch"
JAVA_G1_GC_ARGS="-XX:+UseG1GC -XX:+ExplicitGCInvokesConcurrent -XX:+ParallelRefProcEnabled -XX:+UseStringDeduplication -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:+UnlockDiagnosticVMOptions -XX:G1SummarizeRSetStatsPeriod=1"
JAVA_HEAP_ARGS="-Xms512m -Xmx1024m"
JAVA_AWT_ARGS="-Djava.awt.headless=true"

# Settings (from here: https://wiki.jenkins-ci.org/display/JENKINS/Features+controlled+by+system+properties)
# -hudson.model.UpdateCenter.never -> never download new jenkins versions
# -hudson.model.DownloadService.never -> never download new plugin information
# -jenkins.model.Jenkins.slaveAgentPort -> set the port for the slaves to connect to jenkins
# -jenkins.model.Jenkins.slaveAgentPortEnforce -> enforce the slave connection port. Cannot change it from the UI.
# -jenkins.CLI.disabled -> Disable the CLI through JNLP and HTTP
# -jenkins.install.runSetupWizard -> Skip the install wizzard
JENKINS_JAVA_ARGS="-Dhudson.model.UpdateCenter.never=true -Dhudson.model.DownloadService.never=true -Djenkins.model.Jenkins.slaveAgentPort=$JENKINS_SLAVE_AGENT_PORT -Djenkins.model.Jenkins.slaveAgentPortEnforce=true -Djenkins.CLI.disabled=true -Djenkins.install.runSetupWizard=false"

# Set jenkins to be served at http://localhost:8080/builds
JENKINS_REVERSE_PROXY_ARGS="--prefix=/builds"

# `/sbin/setuser jenkins` runs the given command as the user `jenkins`.
# If you omit that part, the command will be run as root.
exec /sbin/setuser jenkins java $JAVA_SERVER_ARGS $JAVA_G1_GC_ARGS $JAVA_HEAP_ARGS $JAVA_AWT_ARGS $JENKINS_JAVA_ARGS -jar /usr/local/jenkins/jenkins.war $JENKINS_REVERSE_PROXY_ARGS --httpPort=8080 2>&1 | logger
