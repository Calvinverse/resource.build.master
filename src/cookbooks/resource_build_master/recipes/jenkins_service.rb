# frozen_string_literal: true

#
# Cookbook Name:: resource_build_master
# Recipe:: jenkins_service
#
# Copyright 2018, P. van der Velde
#

#
# INSTALL THE CALCULATOR
#

apt_package 'bc' do
  action :install
end

#
# SYSTEMD SERVICE
#

jenkins_http_port = node['jenkins']['port']['http']
jenkins_slave_agent_port = node['jenkins']['port']['slave']

# Create the systemd service for nomad. Set it to depend on the network being up
# so that it won't start unless the network stack is initialized and has an
# IP address

# From here: https://jenkins.io/blog/2016/11/21/gc-tuning/
java_server_args = '-server -XX:+AlwaysPreTouch'
java_g1_gc_args =
  '-XX:+UseG1GC' \
  ' -XX:+ExplicitGCInvokesConcurrent' \
  ' -XX:+ParallelRefProcEnabled' \
  ' -XX:+UseStringDeduplication' \
  ' -XX:+UnlockExperimentalVMOptions' \
  ' -XX:G1NewSizePercent=20' \
  ' -XX:+UnlockDiagnosticVMOptions' \
  ' -XX:G1SummarizeRSetStatsPeriod=1'

java_awt_args = '-Djava.awt.headless=true'

# Make sure java prefers IPv4 over IPv6 because Jolokia doesn't like IPv6
java_ipv4_args = '-Djava.net.preferIPv4Stack=true'

# Settings (from here: https://wiki.jenkins-ci.org/display/JENKINS/Features+controlled+by+system+properties)
# -hudson.model.UpdateCenter.never -> never download new jenkins versions
# -hudson.model.DownloadService.never -> never download new plugin information
# -jenkins.model.Jenkins.slaveAgentPort -> set the port for the slaves to connect to jenkins
# -jenkins.model.Jenkins.slaveAgentPortEnforce -> enforce the slave connection port. Cannot change it from the UI.
# -jenkins.CLI.disabled -> Disable the CLI through JNLP and HTTP
# -jenkins.install.runSetupWizard -> Skip the install wizzard
jenkins_java_args =
  '-Dhudson.model.UpdateCenter.never=true' \
  ' -Dhudson.model.DownloadService.never=true' \
  " -Djenkins.model.Jenkins.slaveAgentPort=#{jenkins_slave_agent_port}" \
  ' -Djenkins.model.Jenkins.slaveAgentPortEnforce=true' \
  ' -Djenkins.CLI.disabled=true' \
  ' -Djenkins.install.runSetupWizard=false'

# Set the Jolokia jar as an agent so that we can export the JMX metrics to influx
# For the settings see here: https://jolokia.org/reference/html/agents.html#agents-jvm
jolokia_jar_path = node['jolokia']['path']['jar_file']
jolokia_agent_host = node['jolokia']['agent']['host']
jolokia_agent_port = node['jolokia']['agent']['port']
jenkins_metrics_args =
  "-javaagent:#{jolokia_jar_path}=" \
  'protocol=http' \
  ",host=#{jolokia_agent_host}" \
  ",port=#{jolokia_agent_port}" \
  ',discoveryEnabled=false'

# Set jenkins to be served at http://localhost:8080/builds
proxy_path = node['jenkins']['proxy_path']
jenkins_args =
  "--httpPort=#{jenkins_http_port}" \
  " --prefix=/#{proxy_path}"

jenkins_user = node['jenkins']['service_user']
jenkins_war_path = node['jenkins']['path']['war_file']
run_jenkins_script = '/usr/local/jenkins/run_jenkins.sh'
file run_jenkins_script do
  action :create
  content <<~SH
    #!/bin/sh

    #
    # Original from here: https://github.com/fabric8io-images/java/blob/master/images/jboss/openjdk8/jdk/run-java.sh
    # Licensed with the Apache 2.0 license as of 2017-10-22
    #

    # ==========================================================
    # Generic run script for running arbitrary Java applications
    #
    # Source and Documentation can be found
    # at https://github.com/fabric8io/run-java-sh
    #
    # ==========================================================

    max_memory() {
      max_mem=$(free -m | grep -oP '\\d+' | head -n 1)
      echo "${max_mem}"
    }

    # Start JVM
    startup() {
      echo "Determining max memory usage ..."
      java_max_memory=""

      # Check for the 'real memory size' and calculate mx from a ratio
      # given (default is 75%)
      max_mem="$(max_memory)"
      if [ "x${max_mem}" != "x0" ]; then
        ratio=70

        mx=$(echo "(${max_mem} * ${ratio} / 100 + 0.5)" | bc | awk '{printf("%d\\n",$1 + 0.5)}')
        java_max_memory="-Xmx${mx}m"

        echo "Maximum memory for VM set to ${max_mem}. Setting max memory for java to ${mx} Mb"
      fi

      java_diagnostics="-XX:NativeMemoryTracking=summary -XX:+PrintGC -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps -XX:+UnlockDiagnosticVMOptions"

      user_java_opts="#{java_server_args} #{java_g1_gc_args} #{java_awt_args} #{java_ipv4_args} #{jenkins_java_args}"
      user_java_jar_opts="#{jenkins_args}"

      echo exec java ${user_java_opts} ${java_max_memory} ${java_diagnostics} #{jenkins_metrics_args} -jar #{jenkins_war_path} ${user_java_jar_opts}
      exec java ${user_java_opts} ${java_max_memory} ${java_diagnostics} #{jenkins_metrics_args} -jar #{jenkins_war_path} ${user_java_jar_opts}
    }

    # =============================================================================
    # Fire up
    startup
  SH
  mode '755'
end

jenkins_service_name = node['jenkins']['service_name']
jenkins_environment_file = node['jenkins']['path']['environment_file']
systemd_service jenkins_service_name do
  action :create
  after %w[network-online.target]
  description 'Jenkins CI system'
  documentation 'https://jenkins.io'
  install do
    wanted_by %w[multi-user.target]
  end
  requires %w[network-online.target]
  service do
    environment_file jenkins_environment_file
    exec_reload "/usr/bin/curl http://localhost:#{jenkins_http_port}/#{proxy_path}/reload"
    exec_start run_jenkins_script
    exec_stop "/usr/bin/curl http://localhost:#{jenkins_http_port}/#{proxy_path}/safeExit"
    restart 'on-failure'
  end
  user jenkins_user
end
