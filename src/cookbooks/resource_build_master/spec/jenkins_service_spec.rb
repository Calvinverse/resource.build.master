# frozen_string_literal: true

require 'spec_helper'

describe 'resource_build_master::jenkins_service' do
  context 'creates the systemd service' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

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

    jenkins_java_args =
      '-Dhudson.model.UpdateCenter.never=true' \
      ' -Dhudson.model.DownloadService.never=true' \
      ' -Djenkins.model.Jenkins.slaveAgentPort=5000' \
      ' -Djenkins.model.Jenkins.slaveAgentPortEnforce=true' \
      ' -Djenkins.CLI.disabled=true' \
      ' -Djenkins.install.runSetupWizard=false'

    # Set jenkins to be served at http://localhost:8080/builds
    jenkins_args =
      '--httpPort=8080' \
      ' --prefix=/builds'

    jenkins_user = 'jenkins'
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
        # given (default is 75%)
        max_mem="$(max_memory)"
        if [ "x${max_mem}" != "x0" ]; then
          ratio=70

          # for some reason the result of the calculation comes up as negative, so we multiply by -1 ...
          mx=$(echo "-1 * (${max_mem} * ${ratio} / 100 + 0.5)" | bc | awk '{printf("%d\\n",$1 + 0.5)}')
          java_max_memory="-Xmx${mx}m"

          echo "Maximum memory for VM set to ${max_mem}. Setting max memory for java to ${mx} Mb"
        fi

        java_diagnostics="-XX:NativeMemoryTracking=summary -XX:+PrintGC -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps -XX:+UnlockDiagnosticVMOptions"

        user_java_opts="#{java_server_args} #{java_g1_gc_args} #{java_awt_args} #{jenkins_java_args}"
        user_java_jar_opts="#{jenkins_args}"

        echo exec /sbin/setuser #{jenkins_user} java ${user_java_opts} ${java_max_memory} ${java_diagnostics} -jar #{jenkins_war_path} ${user_java_jar_opts}
        exec /sbin/setuser #{jenkins_user} java ${user_java_opts} ${java_max_memory} ${java_diagnostics} -jar #{jenkins_war_path} ${user_java_jar_opts}
      }

      # =============================================================================
      # Fire up
      startup
    SH
    it 'creates the /usr/local/jenkins/run_jenkins.sh file' do
      expect(chef_run).to create_file('/usr/local/jenkins/run_jenkins.sh')
        .with_content(jenkins_run_script_content)
    end

    it 'creates the jenkins systemd service' do
      expect(chef_run).to create_systemd_service('jenkins').with(
        action: [:create],
        after: %w[network-online.target],
        description: 'Jenkins CI system',
        wanted_by: %w[multi-user.target],
        exec_reload: '/usr/bin/curl http://localhost:8080/builds/reload',
        exec_start: '/usr/local/jenkins/run_jenkins.sh',
        exec_stop: '/usr/bin/curl http://localhost:8080/builds/safeExit',
        restart: 'on-failure',
        user: 'jenkins'
      )
    end
  end
end
