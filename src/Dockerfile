FROM 192.168.100.2:5000/calvinverse/resource.java.ubuntu:0.1.0
LABEL maintainer "Petrik van der Velde (@petrikvdvelde)"

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Update apt-get so that we can get all the packages
RUN apt-get update


#
# Install GIT
#

RUN apt-get --assume-yes install git


#
# INSTALL JENKINS
#

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000

# Create a user and group first so the IDs get set the same way, even as
# the rest of this may change over time.
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# Expose the jenkins data directory as a volume because it has mutable data
VOLUME /var/jenkins_home
VOLUME /var/jenkins_builds

COPY init.groovy /etc/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.46.3}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=00424d3c851298b29376d1d09d7d3578a2bc4a03acf3914b317c47707cd5739a

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /etc/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /etc/jenkins/jenkins.war" | sha256sum -c -

ENV JENKINS_UC https://updates.jenkins.io
RUN chown -R ${user} "$JENKINS_HOME" /etc/jenkins/ref

# Expose the HTTP port
EXPOSE 8080

# Expose the port used by jenkins to talk to the slaves
EXPOSE 50000

# install the plugins
RUN plugins.sh structs:1.7 junit:1.20 script-security:1.27 matrix-project:1.11 build-failure-analyzer:1.19.0
RUN plugins.sh token-macro:2.1 build-name-setter:1.6.5
RUN plugins.sh build-timeout:1.18
RUN plugins.sh build-user-vars:1.5
RUN plugins.sh credentials:2.1.13 cloudbees-folder:6.0.4
RUN plugins.sh display-url-api:2.0 mailer:1.20 javadoc:1.4 maven-plugin:2.15.1 analysis-core:1.86 email-ext:2.57.2
RUN plugins.sh embeddable-build-status:1.9
RUN plugins.sh workflow-step-api:2.10 workflow-scm-step:2.4 scm-api:2.1.1 ssh-credentials:1.13 git-client:2.4.6 git:3.3.0
RUN plugins.sh greenballs:1.15
RUN plugins.sh gravatar:2.1
RUN plugins.sh hashicorp-vault-plugin:2.1.0
RUN plugins.sh job-dsl:1.63
RUN plugins.sh jackson-api:2.7.3 metrics:3.1.2.9
RUN plugins.sh msbuild:1.27
RUN plugins.sh nomad:0.4
RUN plugins.sh nunit:0.20
RUN plugins.sh powershell:1.3
RUN plugins.sh PrioritySorter:3.5.0
RUN plugins.sh role-strategy:2.4.0
RUN plugins.sh violations:0.7.11
RUN plugins.sh warnings:4.62
RUN plugins.sh workflow-api:2.15 workflow-support:2.14 workflow-durable-task-step:2.11 resource-disposer:0.6 ws-cleanup:0.33

# Update the configuration files

# Mark jenkins as fully installed
RUN echo 2.0 > /usr/share/jenkins/ref/jenkins.install.UpgradeWizard.state

# Add the jenkins configurations for consul
COPY service_jenkins.json /etc/consul/conf.d/service_jenkins.json

# Run jenkins
RUN mkdir /etc/service/jenkins
COPY jenkins.sh /etc/service/jenkins/run
RUN dos2unix /etc/service/jenkins/run
RUN chmod +x /etc/service/jenkins/run

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
