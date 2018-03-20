# frozen_string_literal: true

#
# Cookbook Name:: resource_build_master
# Recipe:: jenkins
#
# Copyright 2018, P. van der Velde
#

jenkins_user = node['jenkins']['service_user']
jenkins_group = node['jenkins']['service_group']
poise_service_user jenkins_user do
  group jenkins_group
end

#
# SET JENKINS_HOME
#

jenkins_home = node['jenkins']['path']['home']
ruby_block 'set_environment_jenkins_home' do
  block do
    file = Chef::Util::FileEdit.new('/etc/environment')
    file.insert_line_if_no_match("JENKINS_HOME=#{jenkins_home}", "JENKINS_HOME=#{jenkins_home}")
    file.write_file
  end
end

#
# INSTALL JENKINS
#

remote_directory jenkins_home do
  action :create
  group jenkins_group
  owner jenkins_user
  mode '0755'
  source 'jenkins'
end

jenkins_war_path = node['jenkins']['path']['war']
remote_file jenkins_war_path do
  action :create
  checksum node['jenkins']['checksum']
  group 'root'
  mode '0755'
  owner 'root'
  source node['jenkins']['url']
end

#
# ALLOW JENKINS THROUGH THE FIREWALL
#

jenkins_http_port = node['jenkins']['port']['http']
firewall_rule 'jenkins-http' do
  command :allow
  description 'Allow Jenkins HTTP traffic'
  dest_port jenkins_http_port
  direction :in
end

jenkins_slave_agent_port = node['jenkins']['port']['slave']
firewall_rule 'jenkins-slave' do
  command :allow
  description 'Allow Jenkins slave traffic'
  dest_port jenkins_slave_agent_port
  direction :in
end

#
# SYSTEMD SERVICE
#

# Create the systemd service for nomad. Set it to depend on the network being up
# so that it won't start unless the network stack is initialized and has an
# IP address

# From here: https://jenkins.io/blog/2016/11/21/gc-tuning/
java_server_args = '-server -XX:+AlwaysPreTouch'
java_g1_gc_args =
  '-XX:+UseG1GC' +
  ' -XX:+ExplicitGCInvokesConcurrent' +
  ' -XX:+ParallelRefProcEnabled' +
  ' -XX:+UseStringDeduplication' +
  ' -XX:+UnlockExperimentalVMOptions' +
  ' -XX:G1NewSizePercent=20' +
  ' -XX:+UnlockDiagnosticVMOptions' +
  ' -XX:G1SummarizeRSetStatsPeriod=1'
java_awt_args = '-Djava.awt.headless=true'

# Settings (from here: https://wiki.jenkins-ci.org/display/JENKINS/Features+controlled+by+system+properties)
# -hudson.model.UpdateCenter.never -> never download new jenkins versions
# -hudson.model.DownloadService.never -> never download new plugin information
# -jenkins.model.Jenkins.slaveAgentPort -> set the port for the slaves to connect to jenkins
# -jenkins.model.Jenkins.slaveAgentPortEnforce -> enforce the slave connection port. Cannot change it from the UI.
# -jenkins.CLI.disabled -> Disable the CLI through JNLP and HTTP
# -jenkins.install.runSetupWizard -> Skip the install wizzard
jenkins_java_args =
  '-Dhudson.model.UpdateCenter.never=true' +
  ' -Dhudson.model.DownloadService.never=true' +
  " -Djenkins.model.Jenkins.slaveAgentPort=#{jenkins_slave_agent_port}" +
  ' -Djenkins.model.Jenkins.slaveAgentPortEnforce=true' +
  ' -Djenkins.CLI.disabled=true' +
  ' -Djenkins.install.runSetupWizard=false'

# Set jenkins to be served at http://localhost:8080/builds
proxy_path = node['jenkins']['proxy_path']
jenkins_args =
  "--httpPort=#{jenkins_http_port}" +
  " --prefix=/#{proxy_path}"

jenkins_service_name = node['jenkins']['service_name']
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
    exec_start "java #{java_server_args} #{java_g1_gc_args} #{java_awt_args} #{jenkins_java_args} -jar #{jenkins_war_path} #{jenkins_args}"
    restart 'on-failure'
  end
  user nomad_user
end

#
# CONSUL FILES
#

# This assumes the health user is called 'health' and the password is 'health'
file '/etc/consul/conf.d/jenkins-http.json' do
  action :create
  content <<~JSON
    {
      "service": {
        "checks": [
          {
            "id": "jenkins_ping",
            "name": "Jenkins HTTP ping",
            "http": "http://localhost:#{jenkins_http_port}/#{proxy_path}/metrics/${GuidHealthPing}/ping",
            "interval": "15s"
          }
        ],
        "enableTagOverride": false,
        "id": "jenkins",
        "name": "build",
        "port": #{},
        "tags": [
          "inactive",
          "edgeproxyprefix-/#{proxy_path}"
        ]
      }
    }
  JSON
end

#
# CONSUL-TEMPLATE FILES
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

# Templates
rabbitmq_config_script_template_file = node['rabbitmq']['consul_template_config_script_file']
file "#{consul_template_template_path}/#{rabbitmq_config_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    {{ if keyExists "config/services/consul/datacenter" }}
    {{ if keyExists "config/services/consul/domain" }}
    echo 'Write the jenkins vault configuration ...'
    cat <<EOT > #{jenkins_home}/com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration.xml
    <?xml version='1.0' encoding='UTF-8'?>
    <com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration plugin="hashicorp-vault-plugin@2.1.0">
      <configuration>
        <vaultUrl>http://secrets.service.{{ key "config/services/consul/domain" }}</vaultUrl>
        <vaultCredentialId>global.vault.approle</vaultCredentialId>
      </configuration>
    </com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration>
    EOT

    echo 'Write the jenkins rabbitmq configuration ...'
    cat <<EOT > #{jenkins_home}/org.jenkinsci.plugins.rabbitmqconsumer.GlobalRabbitmqConfiguration.xml
    <?xml version='1.0' encoding='UTF-8'?>
    <org.jenkinsci.plugins.rabbitmqconsumer.GlobalRabbitmqConfiguration plugin="rabbitmq-consumer@2.7">
      <urlValidator>
        <options>8</options>
        <allowedSchemes>
          <string>amqps</string>
          <string>amqp</string>
        </allowedSchemes>
      </urlValidator>
      <enableConsumer>true</enableConsumer>
      <serviceUri>amqp://{{ key "config/services/queue/protocols/amqp/host" }}.service.{{ key "config/services/consul/domain" }}:{{ key "config/services/queue/protocols/amqp/port" }}/builds</serviceUri>
    {{ with secret "rabbitmq/creds/builds.reader" }}
      {{ if .Data.password }}
        <userName>{{ .Data.username }}</userName>
        <userPassword>{{ .Data.password }}</userPassword>
      {{ end }}
    {{ end }}
      <watchdogPeriod>60000</watchdogPeriod>
      <consumeItems>
        <org.jenkinsci.plugins.rabbitmqconsumer.RabbitmqConsumeItem>
          <appId>remote-build</appId>
          <queueName>builds</queueName>
        </org.jenkinsci.plugins.rabbitmqconsumer.RabbitmqConsumeItem>
      </consumeItems>
      <enableDebug>false</enableDebug>
    </org.jenkinsci.plugins.rabbitmqconsumer.GlobalRabbitmqConfiguration>
    EOT

    echo 'Write the jenkins configuration ...'
    cat <<EOT > #{jenkins_home}/com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration
    EOT

    if ( ! $(systemctl is-enabled --quiet #{jenkins_service_name}) ); then
      systemctl enable #{jenkins_service_name}

      while true; do
        if ( $(systemctl is-enabled --quiet #{jenkins_service_name}) ); then
            break
        fi

        sleep 1
      done
    fi

    systemctl restart #{jenkins_service_name}

    while true; do
      if ( $(systemctl is-active --quiet #{jenkins_service_name}) ); then
          break
      fi

      sleep 1
    done

    {{ else }}
    echo 'Not all Consul K-V values are available. Will not start Jenkins.'
    {{ end }}
    {{ else }}
    echo 'Not all Consul K-V values are available. Will not start Jenkins.'
    {{ end }}
  CONF
  mode '755'
end

rabbitmq_config_script_file = node['rabbitmq']['script_config_file']
file "#{consul_template_config_path}/rabbitmq_config.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{rabbitmq_config_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{rabbitmq_config_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{rabbitmq_config_script_file}"

      # This is the maximum amount of time to wait for the optional command to
      # return. Default is 30s.
      command_timeout = "60s"

      # Exit with an error when accessing a struct or map field/key that does not
      # exist. The default behavior will print "<no value>" when accessing a field
      # that does not exist. It is highly recommended you set this to "true" when
      # retrieving secrets from Vault.
      error_on_missing_key = false

      # This is the permission to render the file. If this option is left
      # unspecified, Consul Template will attempt to match the permissions of the
      # file that already exists at the destination path. If no file exists at that
      # path, the permissions are 0644.
      perms = 0755

      # This option backs up the previously rendered template at the destination
      # path before writing a new one. It keeps exactly one backup. This option is
      # useful for preventing accidental changes to the data without having a
      # rollback strategy.
      backup = true

      # These are the delimiters to use in the template. The default is "{{" and
      # "}}", but for some templates, it may be easier to use a different delimiter
      # that does not conflict with the output file itself.
      left_delimiter  = "{{"
      right_delimiter = "}}"

      # This is the `minimum(:maximum)` to wait before rendering a new template to
      # disk and triggering a command, separated by a colon (`:`). If the optional
      # maximum value is omitted, it is assumed to be 4x the required minimum value.
      # This is a numeric time with a unit suffix ("5s"). There is no default value.
      # The wait value for a template takes precedence over any globally-configured
      # wait.
      wait {
        min = "2s"
        max = "10s"
      }
    }
  HCL
  mode '755'
end
