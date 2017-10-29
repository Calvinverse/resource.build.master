#!/bin/sh

# Copy the vault configuration file from the jenkins templates directory to the jenkins directory
# and replace the following template values:
# - CONSUL_DATACENTER
sed "s/CONSUL_DOMAIN/${CONSUL_DOMAIN_NAME}/g" < /var/jenkins/templates/com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration.xml > /var/jenkins/com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration.xml

# Copy the rabbitmq configuration file from the jenkins templates directory to the jenkins directory
# and replace the following template values:
# - CONSUL_DATACENTER
sed "s/CONSUL_DOMAIN/${CONSUL_DOMAIN_NAME}/g" < /var/jenkins/templates/org.jenkinsci.plugins.rabbitmqconsumer.GlobalRabbitmqConfiguration.xml > /var/jenkins/org.jenkinsci.plugins.rabbitmqconsumer.GlobalRabbitmqConfiguration.xml


# Copy the global jenkins configuration file from the jenkins templates directory to the jenkins directory
# and replace the following template values:
# - CONSUL_DATACENTER
# - NOMAD_DATACENTER
# - NOMAD_REGION
sed "s/CONSUL_DOMAIN/${CONSUL_DOMAIN_NAME}/g" < /var/jenkins/templates/config.xml > /tmp/jenkins/config-1.xml
sed "s/NOMAD_DATACENTER/${NOMAD_DC}/g" < /tmp/jenkins/config-1.xml > /tmp/jenkins/config-2.xml
sed "s/NOMAD_REGION/${NOMAD_REGION}/g" < /tmp/jenkins/config-2.xml > /var/jenkins/config.xml

sh /opt/java/run/run-java.sh 2>&1 | logger
