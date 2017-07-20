FROM 192.168.100.2:5000/calvinverse/resource.java.jre.ubuntu:0.1.0
LABEL maintainer "Petrik van der Velde (@petrikvdvelde)"

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

#
# Install tools via apt
#
RUN apt-get update && \
    apt-get --assume-yes install git && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


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

ENV JENKINS_BUILD_DATA /var/builds
RUN mkdir /var/builds

# Update the configuration files
COPY jenkins/ $JENKINS_HOME
COPY jenkins.war /usr/local/jenkins/jenkins.war

# Expose the HTTP port
EXPOSE 8080

# Expose the port used by jenkins to talk to the slaves
# If this port is changed then it also needs to be changed in the jenkins config.xml file.
EXPOSE 50000

RUN chown -R ${user} "$JENKINS_HOME"
RUN chown -R ${user} /usr/local/jenkins

# Run jenkins
RUN mkdir /etc/service/jenkins
COPY jenkins.sh /etc/service/jenkins/run
RUN dos2unix /etc/service/jenkins/run
RUN chmod +x /etc/service/jenkins/run


#
# ADD THE SERVICE TO CONSUL
#

# Add the jenkins configurations for consul
COPY service_jenkins.json /etc/consul/conf.d/service_jenkins.json


#
# CLEAN-UP
#

# Re-create the /tmp directory so that jenkins can use it for workspaces etc.
# Make sure that everybody can write to it
RUN mkdir -p /tmp && chmod 1777 /tmp
