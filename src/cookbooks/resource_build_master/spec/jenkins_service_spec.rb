# frozen_string_literal: true

require 'spec_helper'

describe 'resource_build_master::jenkins_service' do
  context 'creates the systemd service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    java_server_args = '-server -XX:+AlwaysPreTouch'
    java_gc_args =
      '-XX:+UseConcMarkSweepGC' \
      ' -XX:+ExplicitGCInvokesConcurrent' \
      ' -XX:+ParallelRefProcEnabled' \
      ' -XX:+UseStringDeduplication' \
      ' -XX:+CMSParallelRemarkEnabled' \
      ' -XX:+CMSIncrementalMode' \
      ' -XX:CMSInitiatingOccupancyFraction=75'
    java_awt_args = '-Djava.awt.headless=true'

    java_ipv4_args = '-Djava.net.preferIPv4Stack=true'

    java_diagnostics =
      '-Xloggc:\var\log\jenkins_gc-%t.log' \
      ' -XX:NumberOfGCLogFiles=10' \
      ' -XX:+UseGCLogFileRotation' \
      ' -XX:GCLogFileSize=25m' \
      ' -XX:+PrintGC' \
      ' -XX:+PrintGCDateStamps' \
      ' -XX:+PrintGCDetails' \
      ' -XX:+PrintHeapAtGC' \
      ' -XX:+PrintGCCause' \
      ' -XX:+PrintTenuringDistribution' \
      ' -XX:+PrintReferenceGC' \
      ' -XX:+PrintAdaptiveSizePolicy' \
      ' -XX:+HeapDumpOnOutOfMemoryError'

    jenkins_java_args =
      '-Dhudson.model.UpdateCenter.never=true' \
      ' -Dhudson.model.DownloadService.never=true' \
      ' -Djenkins.model.Jenkins.slaveAgentPort=5000' \
      ' -Djenkins.model.Jenkins.slaveAgentPortEnforce=true' \
      ' -Djenkins.CLI.disabled=true' \
      ' -Djenkins.install.runSetupWizard=false'

    jenkins_metrics_args =
      '-javaagent:/usr/local/jolokia/jolokia.jar=' \
      'protocol=http' \
      ',host=127.0.0.1' \
      ',port=8090' \
      ',discoveryEnabled=false'

    # Set jenkins to be served at http://localhost:8080/builds
    jenkins_args =
      '--httpPort=8080' \
      ' --prefix=/builds'

    jenkins_war_path = '/usr/local/jenkins/jenkins.war'
    jenkins_run_script_content = <<~SH
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
        # given (default is 70%)
        max_mem="$(max_memory)"
        if [ "x${max_mem}" != "x0" ]; then
          ratio=70

          mx=$(echo "(${max_mem} * ${ratio} / 100 + 0.5)" | bc | awk '{printf("%d\\n",$1 + 0.5)}')
          java_max_memory="-Xmx${mx}m -Xms${mx}m"

          echo "Maximum memory for VM set to ${max_mem}. Setting max memory for java to ${mx} Mb"
        fi

        user_java_opts="#{java_server_args} #{java_gc_args} #{java_awt_args} #{java_ipv4_args} #{jenkins_java_args}"
        user_java_jar_opts="#{jenkins_args}"

        echo nohup java ${user_java_opts} ${java_max_memory} #{java_diagnostics} #{jenkins_metrics_args} -jar #{jenkins_war_path} ${user_java_jar_opts}
        nohup java ${user_java_opts} ${java_max_memory} #{java_diagnostics} #{jenkins_metrics_args} -jar #{jenkins_war_path} ${user_java_jar_opts} 2>&1 &
        echo "$!" >"/usr/local/jenkins/jenkins_pid"
      }

      # =============================================================================
      # Fire up
      startup
    SH
    it 'creates the /usr/local/jenkins/run_jenkins.sh file' do
      expect(chef_run).to create_file('/usr/local/jenkins/run_jenkins.sh')
        .with_content(jenkins_run_script_content)
        .with(
          group: 'jenkins',
          owner: 'jenkins',
          mode: '0550'
        )
    end

    it 'creates the jenkins systemd service' do
      expect(chef_run).to create_systemd_service('jenkins').with(
        action: [:create],
        unit_after: %w[network-online.target],
        unit_description: 'Jenkins CI system',
        install_wanted_by: %w[multi-user.target],
        service_exec_reload: '/usr/bin/curl http://localhost:8080/builds/reload',
        service_exec_start: '/usr/local/jenkins/run_jenkins.sh',
        service_exec_stop: '/usr/bin/curl http://localhost:8080/builds/safeExit',
        service_pid_file: '/usr/local/jenkins/jenkins_pid',
        service_restart: 'on-failure',
        service_type: 'forking',
        service_user: 'jenkins'
      )
    end
  end
end
