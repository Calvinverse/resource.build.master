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

ENV JENKINS_SLAVE_AGENT_PORT 50000
ENV JENKINS_HOME /var/jenkins

# Create a user and group first so the IDs get set the same way, even as
# the rest of this may change over time.
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=2000

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# Expose the build data directory because it contains the information describing the builds
ENV JENKINS_BUILD_DATA /var/builds
VOLUME /var/builds

# Update the configuration files
COPY jenkins/ $JENKINS_HOME

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.46.3}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=00424d3c851298b29376d1d09d7d3578a2bc4a03acf3914b317c47707cd5739a

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
# see https://github.com/docker/docker/issues/8331
RUN curl --fail --silent --show-error --location --create-dirs --output /usr/local/jenkins/jenkins.war "${JENKINS_URL}" && \
    echo "${JENKINS_SHA} /usr/local/jenkins/jenkins.war" | sha256sum -c -

ENV JENKINS_UC https://updates.jenkins.io

# Expose the HTTP port
EXPOSE 8080

# Expose the port used by jenkins to talk to the slaves
# If this port is changed then it also needs to be changed in the jenkins config.xml file.
EXPOSE 50000

# install the plugins
COPY install-plugins.sh /tmp/install-plugins.sh
COPY plugins.txt /tmp/plugins.txt
RUN dos2unix /tmp/install-plugins.sh && \
    dos2unix /tmp/plugins.txt && \
    /tmp/install-plugins.sh /tmp/plugins.txt && \
    rm -rf /tmp

RUN chown -R ${user} "$JENKINS_HOME"
RUN chown -R ${user} /usr/local/jenkins

# Add the jenkins configurations for consul
COPY service_jenkins.json /etc/consul/conf.d/service_jenkins.json

# Run jenkins
RUN mkdir /etc/service/jenkins
COPY jenkins.sh /etc/service/jenkins/run
RUN dos2unix /etc/service/jenkins/run
RUN chmod +x /etc/service/jenkins/run

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Re-create the /tmp directory so that jenkins can use it for workspaces etc.
# Make sure that everybody can write to it
RUN mkdir -p /tmp && chmod 1777 /tmp
