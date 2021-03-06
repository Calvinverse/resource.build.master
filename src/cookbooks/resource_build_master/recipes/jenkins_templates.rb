# frozen_string_literal: true

#
# Cookbook Name:: resource_build_master
# Recipe:: jenkins_templates
#
# Copyright 2018, P. van der Velde
#

#
# FLAG FILES
#

flag_groovy_ad = '/var/log/jenkins_groovy_ad.log'
file flag_groovy_ad do
  action :create
  content <<~TXT
    NotInitialized
  TXT
  group 'root'
  mode '0770'
  owner 'root'
end

flag_config = '/var/log/jenkins_config.log'
file flag_config do
  action :create
  content <<~TXT
    NotInitialized
  TXT
  group 'root'
  mode '0770'
  owner 'root'
end

flag_credentials_config = '/var/log/jenkins_casc_credentials.log'
file flag_credentials_config do
  action :create
  content <<~TXT
    NotInitialized
  TXT
  group 'root'
  mode '0770'
  owner 'root'
end

flag_logstash_config = '/var/log/jenkins_casc_logstash.log'
file flag_logstash_config do
  action :create
  content <<~TXT
    NotInitialized
  TXT
  group 'root'
  mode '0770'
  owner 'root'
end

flag_location_config = '/var/log/jenkins_location_config.log'
file flag_location_config do
  action :create
  content <<~TXT
    NotInitialized
  TXT
  group 'root'
  mode '0770'
  owner 'root'
end

flag_mailer_config = '/var/log/jenkins_mailer_config.log'
file flag_mailer_config do
  action :create
  content <<~TXT
    NotInitialized
  TXT
  group 'root'
  mode '0770'
  owner 'root'
end

flag_rabbitmq_config = '/var/log/jenkins_rabbitmq_config.log'
file flag_rabbitmq_config do
  action :create
  content <<~TXT
    NotInitialized
  TXT
  group 'root'
  mode '0770'
  owner 'root'
end

flag_vault_config = '/var/log/jenkins_vault_config.log'
file flag_vault_config do
  action :create
  content <<~TXT
    NotInitialized
  TXT
  group 'root'
  mode '0770'
  owner 'root'
end

#
# DIRECTORIES
#

jenkins_build_data_path = node['jenkins']['path']['build_data']
directory jenkins_build_data_path do
  action :create
  group node['jenkins']['service_group']
  mode '0770'
  owner node['jenkins']['service_user']
end

#
# CONSUL-TEMPLATE FILES
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

jenkins_home = node['jenkins']['path']['home']

jenkins_service_name = node['jenkins']['service_name']
jenkins_slave_agent_port = node['jenkins']['port']['slave']

#
# ACTIVE DIRECTORY CONFIGURATION
#

jenkins_groovy_ad_script_template_file = node['jenkins']['consul_template']['groovy_ad_script_file']
file "#{consul_template_template_path}/#{jenkins_groovy_ad_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    {{ if keyExists "config/environment/directory/initialized" }}
    FLAG=$(cat #{flag_groovy_ad})
    if [ "$FLAG" = "NotInitialized" ]; then
        echo "Write the jenkins active directory groovy script ..."
        cat <<'EOT' > #{jenkins_home}/init.groovy.d/p050.activedirectory.groovy
    import hudson.plugins.active_directory.*
    import jenkins.model.*

    def instance = Jenkins.getInstance();
    def ActiveDirectoryDomain adDomain = new ActiveDirectoryDomain(
      // name
      "{{ key "config/environment/directory/name" }}",

      // servers
      "{{ range ls "config/environment/directory/endpoints/hosts" }}{{ .Value }},{{ end }}",

      // site
      "",

      // bindName,
      "{{ key "config/environment/directory/users/bindcn" }}",

      // bindPassword
      {{ with secret "secret/environment/directory/users/bind" }}{{ if .Data.password }}"{{ .Data.password }}"{{ end }}{{ end }});
    def domains = new ArrayList<ActiveDirectoryDomain>();
    domains.add(adDomain);

    def securityRealm = new ActiveDirectorySecurityRealm(
      // domain
      "",

      // domains
      domains,

      // site
      "",

      // bindName
      "",

      // bindPassword
      "",

      // server
      "",

      // groupLookupStrategy
      GroupLookupStrategy.RECURSIVE,

      // removeIrrelevantGroups
      false,

      // customDomain
      true,

      // cache
      null,

      // startTls
      true,

      // tlsConfiguration
      null,

      // internalUsersDatabase: Note that this user name should be updated if the admin user name changes
      new ActiveDirectoryInternalUsersDatabase("admin"));

    instance.setSecurityRealm(securityRealm)
    instance.save()
    EOT

        chown #{node['jenkins']['service_user']}:#{node['jenkins']['service_group']} #{jenkins_home}/init.groovy.d/p050.activedirectory.groovy
        chmod 550 #{jenkins_home}/init.groovy.d/p050.activedirectory.groovy

        if ( $(systemctl is-enabled --quiet #{jenkins_service_name}) ); then
          if ( ! (systemctl is-active --quiet #{jenkins_service_name}) ); then
            systemctl restart #{jenkins_service_name}
          fi
        fi

        echo "Initialized" > #{flag_groovy_ad}
    fi

    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

jenkins_groovy_ad_script_file = node['jenkins']['consul_template']['groovy_ad_file']
file "#{consul_template_config_path}/jenkins_groovy_ad.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{jenkins_groovy_ad_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{jenkins_groovy_ad_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{jenkins_groovy_ad_script_file}"

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
      perms = 0550

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
  group 'root'
  mode '0550'
  owner 'root'
end

#
# JENKINS CONFIGURATION
#

jenkins_config_script_template_file = node['jenkins']['consul_template']['config_script_file']
file "#{consul_template_template_path}/#{jenkins_config_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    {{ if keyExists "config/services/consul/domain" }}
    {{ if keyExists "config/environment/directory/query/groups/builds/administrators" }}
    {{ if keyExists "config/environment/directory/query/groups/builds/agent" }}
    FLAG=$(cat #{flag_config})
    if [ "$FLAG" = "NotInitialized" ]; then
        echo "Write the jenkins configuration ..."
        cat <<'EOT' > #{jenkins_home}/config.xml
    <?xml version='1.0' encoding='UTF-8'?>
    <hudson>
      <version></version>

      <!-- JENKINS SECURITY -->
      <useSecurity>true</useSecurity>

      <!--
            If the role names change then the 'security.groovy' script in the 'init.goovy.d' directory might need
            to be updated as well.
        -->
      <authorizationStrategy class="com.michelin.cio.hudson.plugins.rolestrategy.RoleBasedAuthorizationStrategy">
        <roleMap type="projectRoles"/>
        <roleMap type="globalRoles">
          <role name="global.admin" pattern=".*">
            <permissions>
              <permission>com.cloudbees.plugins.credentials.CredentialsProvider.Create</permission>
              <permission>com.cloudbees.plugins.credentials.CredentialsProvider.Delete</permission>
              <permission>com.cloudbees.plugins.credentials.CredentialsProvider.ManageDomains</permission>
              <permission>com.cloudbees.plugins.credentials.CredentialsProvider.Update</permission>
              <permission>com.cloudbees.plugins.credentials.CredentialsProvider.View</permission>
              <permission>com.sonyericsson.jenkins.plugins.bfa.PluginImpl.RemoveCause</permission>
              <permission>com.sonyericsson.jenkins.plugins.bfa.PluginImpl.UpdateCauses</permission>
              <permission>com.sonyericsson.jenkins.plugins.bfa.PluginImpl.ViewCauses</permission>
              <permission>hudson.model.Computer.Build</permission>
              <permission>hudson.model.Computer.Configure</permission>
              <permission>hudson.model.Computer.Connect</permission>
              <permission>hudson.model.Computer.Create</permission>
              <permission>hudson.model.Computer.Delete</permission>
              <permission>hudson.model.Computer.Disconnect</permission>
              <permission>hudson.model.Computer.Provision</permission>
              <permission>hudson.model.Hudson.Administer</permission>
              <permission>hudson.model.Hudson.Read</permission>
              <permission>hudson.model.Item.Build</permission>
              <permission>hudson.model.Item.Cancel</permission>
              <permission>hudson.model.Item.Configure</permission>
              <permission>hudson.model.Item.Create</permission>
              <permission>hudson.model.Item.Delete</permission>
              <permission>hudson.model.Item.Discover</permission>
              <permission>hudson.model.Item.Move</permission>
              <permission>hudson.model.Item.Read</permission>
              <permission>hudson.model.Item.ViewStatus</permission>
              <permission>hudson.model.Item.Workspace</permission>
              <permission>hudson.model.Run.Delete</permission>
              <permission>hudson.model.Run.Replay</permission>
              <permission>hudson.model.Run.Update</permission>
              <permission>hudson.model.View.Configure</permission>
              <permission>hudson.model.View.Create</permission>
              <permission>hudson.model.View.Delete</permission>
              <permission>hudson.model.View.Read</permission>
              <permission>hudson.scm.SCM.Tag</permission>
              <permission>jenkins.metrics.api.Metrics.HealthCheck</permission>
              <permission>jenkins.metrics.api.Metrics.ThreadDump</permission>
              <permission>jenkins.metrics.api.Metrics.View</permission>
            </permissions>
            <assignedSIDs>
              <sid>admin</sid>
              <sid>{{ key "config/environment/directory/query/groups/builds/administrators" }}</sid>
            </assignedSIDs>
          </role>
          <role name="global.agent" pattern=".*">
            <permissions>
              <permission>hudson.model.Computer.Create</permission>
            </permissions>
            <assignedSIDs>
              <sid>{{ key "config/environment/directory/query/groups/builds/agent" }}</sid>
            </assignedSIDs>
          </role>
          <role name="global.anonymous" pattern=".*">
            <permissions>
              <permission>hudson.model.Item.Discover</permission>
            </permissions>
            <assignedSIDs>
              <sid>anonymous</sid>
            </assignedSIDs>
          </role>
          <role name="global.authenticated" pattern=".*">
            <permissions>
              <permission>com.sonyericsson.jenkins.plugins.bfa.PluginImpl.ViewCauses</permission>
              <permission>hudson.model.Hudson.Read</permission>
              <permission>hudson.model.Item.Build</permission>
            </permissions>
            <assignedSIDs>
              <sid>{{ key "config/environment/directory/query/groups/builds/agent" }}</sid>
            </assignedSIDs>
          </role>
        </roleMap>
        <roleMap type="slaveRoles">
          <role name="agent.connect" pattern=".*">
            <permissions>
              <permission>hudson.model.Computer.Connect</permission>
              <permission>hudson.model.Computer.Disconnect</permission>
            </permissions>
            <assignedSIDs>
              <sid>{{ key "config/environment/directory/query/groups/builds/agent" }}</sid>
            </assignedSIDs>
          </role>
          <role name="agent.build" pattern=".*">
            <permissions>
              <permission>hudson.model.Computer.Build</permission>
            </permissions>
            <assignedSIDs>
              <sid>{{ key "config/environment/directory/query/groups/builds/agent" }}</sid>
            </assignedSIDs>
          </role>
        </roleMap>
      </authorizationStrategy>
      <securityRealm class="hudson.security.HudsonPrivateSecurityRealm">
        <disableSignup>true</disableSignup>
        <enableCaptcha>false</enableCaptcha>
      </securityRealm>
      <disableRememberMe>false</disableRememberMe>
      <crumbIssuer class="hudson.security.csrf.DefaultCrumbIssuer">
        <excludeClientIPFromCrumb>false</excludeClientIPFromCrumb>
      </crumbIssuer>

      <!-- SLAVES -->
      <slaveAgentPort>#{jenkins_slave_agent_port}</slaveAgentPort>
      <enabledAgentProtocols>
        <string>JNLP4-connect</string>
      </enabledAgentProtocols>
      <disabledAgentProtocols>
        <string>JNLP-connect</string>
        <string>JNLP2-connect</string>
        <string>JNLP3-connect</string>
      </disabledAgentProtocols>

      <!-- JENKINS DIRECTORIES -->
      <!--
            The global directory where the job workspaces are located on the master. Since we don't run
            jobs on the master we don't care where the workspaces are placed. A temp directory will do
        -->
      <workspaceDir>/tmp/jenkins/workspace/\${ITEM_FULL_NAME}</workspaceDir>
      <!--
            The global directory where the build data (logs etc.) will be kept.
        -->
      <buildsDir>#{jenkins_build_data_path}/\${ITEM_FULL_NAME}</buildsDir>

      <!-- MASTER EXECUTORS -->
      <!--
            By default we don't want the master to execute any jobs, so we set
            the executors to zero.
        -->
      <numExecutors>0</numExecutors>
      <mode>EXCLUSIVE</mode>
      <label></label>

      <!-- SCM -->
      <quietPeriod>5</quietPeriod>
      <scmCheckoutRetryCount>0</scmCheckoutRetryCount>

      <!-- JENKINS ADMIN -->
      <disabledAdministrativeMonitors/>

      <!-- PROJECT NAMING -->
      <projectNamingStrategy class="jenkins.model.ProjectNamingStrategy$DefaultProjectNamingStrategy"/>

      <!-- ALLOW HTML IN EDIT BOXES -->
      <markupFormatter class="hudson.markup.RawHtmlMarkupFormatter" plugin="antisamy-markup-formatter@1.5">
        <disableSyntaxHighlighting>false</disableSyntaxHighlighting>
      </markupFormatter>

      <jdks/>
      <viewsTabBar class="hudson.views.DefaultViewsTabBar"/>
      <myViewsTabBar class="hudson.views.DefaultMyViewsTabBar"/>
      <clouds/>
      <views>
        <hudson.model.AllView>
          <owner class="hudson" reference="../../.."/>
          <name>All</name>
          <filterExecutors>false</filterExecutors>
          <filterQueue>false</filterQueue>
          <properties class="hudson.model.View$PropertyList"/>
        </hudson.model.AllView>
      </views>
      <primaryView>All</primaryView>
      <nodeProperties/>
      <globalNodeProperties/>
    </hudson>
    EOT

        chown #{node['jenkins']['service_user']}:#{node['jenkins']['service_group']} #{jenkins_home}/config.xml
        chmod 770 #{jenkins_home}/config.xml

        if ( $(systemctl is-enabled --quiet #{jenkins_service_name}) ); then
          if ( ! (systemctl is-active --quiet #{jenkins_service_name}) ); then
            systemctl restart #{jenkins_service_name}
          fi
        fi

        echo "Initialized" > #{flag_config}
    fi

    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

jenkins_config_script_file = node['jenkins']['consul_template']['config_file']
file "#{consul_template_config_path}/jenkins_configuration.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{jenkins_config_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{jenkins_config_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{jenkins_config_script_file}"

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
      perms = 0550

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
  group 'root'
  mode '0550'
  owner 'root'
end

#
# LOCATION CONFIGURATION
#

jenkins_location_config_script_template_file = node['jenkins']['consul_template']['location_config_script_file']
file "#{consul_template_template_path}/#{jenkins_location_config_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    {{ if keyExists "config/environment/mail/suffix" }}
    {{ if keyExists "config/services/builds/url/proxy" }}
    FLAG=$(cat #{flag_location_config})
    if [ "$FLAG" = "NotInitialized" ]; then
        echo "Write the jenkins location configuration ..."
        cat <<'EOT' > #{jenkins_home}/jenkins.model.JenkinsLocationConfiguration.xml
    <?xml version='1.0' encoding='UTF-8'?>
    <jenkins.model.JenkinsLocationConfiguration>
      <adminAddress>Builds &lt;builds@{{ key "config/environment/mail/suffix" }}&gt;</adminAddress>
      <jenkinsUrl>{{ key "config/services/builds/url/proxy" }}</jenkinsUrl>
    </jenkins.model.JenkinsLocationConfiguration>
    EOT

        chown #{node['jenkins']['service_user']}:#{node['jenkins']['service_group']} #{jenkins_home}/jenkins.model.JenkinsLocationConfiguration.xml
        chmod 770 #{jenkins_home}/jenkins.model.JenkinsLocationConfiguration.xml

        if ( $(systemctl is-enabled --quiet #{jenkins_service_name}) ); then
          if ( ! (systemctl is-active --quiet #{jenkins_service_name}) ); then
            systemctl restart #{jenkins_service_name}
          fi
        fi

        echo "Initialized" > #{flag_location_config}
    fi

    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

jenkins_location_config_script_file = node['jenkins']['consul_template']['location_config_file']
file "#{consul_template_config_path}/jenkins_location_configuration.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{jenkins_location_config_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{jenkins_location_config_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{jenkins_location_config_script_file}"

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
      perms = 0550

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
  group 'root'
  mode '0550'
  owner 'root'
end

#
# MAILER CONFIGURATION
#

jenkins_mailer_config_script_template_file = node['jenkins']['consul_template']['mailer_config_script_file']
file "#{consul_template_template_path}/#{jenkins_mailer_config_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    {{ if keyExists "config/environment/mail/smtp/host" }}
    {{ if keyExists "config/environment/mail/suffix" }}
    {{ if keyExists "config/services/builds/url/proxy" }}
    FLAG=$(cat #{flag_mailer_config})
    if [ "$FLAG" = "NotInitialized" ]; then
        echo "Write the jenkins mailer configuration ..."
        cat <<'EOT' > #{jenkins_home}/hudson.tasks.Mailer.xml
    <?xml version='1.0' encoding='UTF-8'?>
    <hudson.tasks.Mailer_-DescriptorImpl plugin="mailer@1.19">
      <defaultSuffix>@{{ key "config/environment/mail/suffix" }}</defaultSuffix>
      <hudsonUrl>{{ key "config/services/builds/url/proxy" }}</hudsonUrl>
      <smtpHost>{{ key "config/environment/mail/smtp/host" }}</smtpHost>
      <useSsl>false</useSsl>
      <charset>UTF-8</charset>
    </hudson.tasks.Mailer_-DescriptorImpl>
    EOT

        chown #{node['jenkins']['service_user']}:#{node['jenkins']['service_group']} #{jenkins_home}/hudson.tasks.Mailer.xml
        chmod 770 #{jenkins_home}/hudson.tasks.Mailer.xml

        if ( $(systemctl is-enabled --quiet #{jenkins_service_name}) ); then
          if ( ! (systemctl is-active --quiet #{jenkins_service_name}) ); then
            systemctl restart #{jenkins_service_name}
          fi
        fi

        echo "Initialized" > #{flag_mailer_config}
    fi

    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

jenkins_mailer_config_script_file = node['jenkins']['consul_template']['mailer_config_file']
file "#{consul_template_config_path}/jenkins_mailer_configuration.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{jenkins_mailer_config_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{jenkins_mailer_config_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{jenkins_mailer_config_script_file}"

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
      perms = 0550

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
  group 'root'
  mode '0550'
  owner 'root'
end

#
# VAULT CONFIGURATION
#

jenkins_vault_config_script_template_file = node['jenkins']['consul_template']['vault_config_script_file']
file "#{consul_template_template_path}/#{jenkins_vault_config_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    {{ if keyExists "config/services/consul/domain" }}
    {{ if keyExists "config/services/secrets/protocols/http/host" }}
    {{ if keyExists "config/services/secrets/protocols/http/port" }}
    FLAG=$(cat #{flag_vault_config})
    if [ "$FLAG" = "NotInitialized" ]; then
        echo "Write the jenkins vault configuration ..."
        cat <<'EOT' > #{jenkins_home}/com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration.xml
    <?xml version='1.0' encoding='UTF-8'?>
    <com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration plugin="hashicorp-vault-plugin@2.1.0">
    <configuration>
        <vaultUrl>http://{{ key "config/services/secrets/protocols/http/host" }}.service.{{ key "config/services/consul/domain" }}:{{ key "config/services/secrets/protocols/http/port" }}</vaultUrl>
        <vaultCredentialId>global.vault.approle</vaultCredentialId>
    </configuration>
    </com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration>
    EOT

        chown #{node['jenkins']['service_user']}:#{node['jenkins']['service_group']} #{jenkins_home}/com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration.xml
        chmod 770 #{jenkins_home}/com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration.xml

        if ( $(systemctl is-enabled --quiet #{jenkins_service_name}) ); then
          if ( ! (systemctl is-active --quiet #{jenkins_service_name}) ); then
            systemctl restart #{jenkins_service_name}
          fi
        fi

        echo "Initialized" > #{flag_vault_config}
    fi

    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

jenkins_vault_config_script_file = node['jenkins']['consul_template']['vault_config_file']
file "#{consul_template_config_path}/jenkins_vault_configuration.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{jenkins_vault_config_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{jenkins_vault_config_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{jenkins_vault_config_script_file}"

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
      perms = 0550

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
  group 'root'
  mode '0550'
  owner 'root'
end

#
# RABBITMQ CONFIGURATION
#

jenkins_casc_path = node['jenkins']['path']['casc']

jenkins_rabbitmq_config_script_template_file = node['jenkins']['consul_template']['rabbitmq_config_script_file']
file "#{consul_template_template_path}/#{jenkins_rabbitmq_config_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    {{ if keyExists "config/services/consul/datacenter" }}
    {{ if keyExists "config/services/consul/domain" }}
    {{ if keyExists "config/services/queue/protocols/amqp/host" }}
    {{ if keyExists "config/services/queue/builds/vhost" }}
    FLAG=$(cat #{flag_rabbitmq_config})
    echo "Write the jenkins rabbitmq configuration ..."
    cat <<'EOT' > #{jenkins_casc_path}/rabbitmq_consumer.yaml
    unclassified:
      globalRabbitmqConfiguration:
        enableConsumer: true
        serviceUri: "amqp://{{ key "config/services/queue/protocols/amqp/host" }}.service.{{ key "config/services/consul/domain" }}:{{ key "config/services/queue/protocols/amqp/port" }}/{{ key "config/services/queue/builds/vhost" }}"
      {{ with secret "secret/services/queue/users/build/triggers" }}
      {{ if .Data.password }}
        userName: "{{ .Data.username }}"
        userPassword: "{{ .Data.password }}"
      {{ end }}
      {{ end }}
        watchdogPeriod: 60000
        consumeItems:
        - appId: "remote-build"
          queueName: "jenkins.trigger"
    EOT

    chown #{node['jenkins']['service_user']}:#{node['jenkins']['service_group']} #{jenkins_casc_path}/rabbitmq_consumer.yaml
    chmod 770 #{jenkins_casc_path}/rabbitmq_consumer.yaml

    if ( $(systemctl is-enabled --quiet #{jenkins_service_name}) ); then
      if ( ! (systemctl is-active --quiet #{jenkins_service_name}) ); then
        systemctl restart #{jenkins_service_name}
      fi
    fi

    echo "Initialized" > #{flag_rabbitmq_config}

    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
    {{ else }}
    echo "Not all Consul K-V values are available. Will not start Jenkins."
    {{ end }}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

jenkins_rabbitmq_config_script_file = node['jenkins']['consul_template']['rabbitmq_config_file']
file "#{consul_template_config_path}/jenkins_rabbitmq_configuration.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{jenkins_rabbitmq_config_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{jenkins_rabbitmq_config_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{jenkins_rabbitmq_config_script_file}"

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
      perms = 0550

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
  group 'root'
  mode '0550'
  owner 'root'
end

#
# CREDENTIALS CONFIGURATION
#

jenkins_credentials_config_script_template_file = node['jenkins']['consul_template']['credentials_config_script_file']
file "#{consul_template_template_path}/#{jenkins_credentials_config_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    FLAG=$(cat #{flag_credentials_config})
    echo "Write the jenkins credentials configuration ..."
    cat <<'EOT' > #{jenkins_casc_path}/credentials.yaml
    credentials:
      system:
        domainCredentials:
          - domain :
            credentials:
            {{ range $collection, $collectionPairs := tree "config/projects" | byKey }}
            {{ range $project, $projectPairs := tree (printf "config/projects/%s" $collection) | byKey }}
              - usernamePassword:
                  scope: GLOBAL
                  id: {{ $collection }}-{{ $project }}
                  description: "Credentials to access the {{ $collection }}/{{ $project }} project"
                  username: {{ key (printf "config/projects/%s/%s/user" $collection $project) }}
                  password: {{ with secret (printf "secret/projects/%s/%s/user" $collection $project ) }}{{ if .Data.password }}"{{ .Data.password }}"{{ end }}{{ end }}
            {{ end }}
            {{ end }}
    EOT

    chown #{node['jenkins']['service_user']}:#{node['jenkins']['service_group']} #{jenkins_casc_path}/credentials.yaml
    chmod 550 #{jenkins_casc_path}/credentials.yaml

    if ( $(systemctl is-enabled --quiet #{jenkins_service_name}) ); then
      if ( ! (systemctl is-active --quiet #{jenkins_service_name}) ); then
        systemctl restart #{jenkins_service_name}
      fi
    fi

    echo "Initialized" > #{flag_credentials_config}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

jenkins_credentials_config_script_file = node['jenkins']['consul_template']['credentials_file']
file "#{consul_template_config_path}/jenkins_credentials_configuration.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{jenkins_credentials_config_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{jenkins_credentials_config_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{jenkins_credentials_config_script_file}"

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
      perms = 0550

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
  group 'root'
  mode '0550'
  owner 'root'
end

#
# LOGSTASH CONFIGURATION
#

jenkins_casc_path = node['jenkins']['path']['casc']
jenkins_logstash_config_script_template_file = node['jenkins']['consul_template']['logstash_config_script_file']
file "#{consul_template_template_path}/#{jenkins_logstash_config_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    FLAG=$(cat #{flag_logstash_config})
    echo "Write the jenkins logstash configuration ..."
    cat <<'EOT' > #{jenkins_casc_path}/logstash.yaml
    unclassified:
      logstashConfiguration:
        enableGlobally: true
        enabled: true
        logstashIndexer:
          rabbitMq:
            host: "{{ key "config/services/queue/protocols/amqp/host" }}.service.{{ key "config/services/consul/domain" }}"
            port: {{ key "config/services/queue/protocols/amqp/port" }}
            virtualHost: "{{ key "config/services/queue/logs/builds/vhost" }}"
            queue: "{{ key "config/services/queue/logs/builds/queue" }}"
          {{ with secret "secret/services/queue/users/build/logs" }}
          {{ if .Data.password }}
            username: "{{ .Data.username }}"
            password: "{{ .Data.password }}"
          {{ end }}
          {{ end }}
        milliSecondTimestamps: true
    EOT

    chown #{node['jenkins']['service_user']}:#{node['jenkins']['service_group']} #{jenkins_casc_path}/logstash.yaml
    chmod 550 #{jenkins_casc_path}/logstash.yaml

    if ( $(systemctl is-enabled --quiet #{jenkins_service_name}) ); then
      if ( ! (systemctl is-active --quiet #{jenkins_service_name}) ); then
        systemctl restart #{jenkins_service_name}
      fi
    fi

    echo "Initialized" > #{flag_logstash_config}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

jenkins_logstash_config_script_file = node['jenkins']['consul_template']['logstash_file']
file "#{consul_template_config_path}/jenkins_logstash_configuration.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{jenkins_logstash_config_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{jenkins_logstash_config_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{jenkins_logstash_config_script_file}"

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
      perms = 0550

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
  group 'root'
  mode '0550'
  owner 'root'
end

#
# START SCRIPT
#

jenkins_start_script_template_file = node['jenkins']['consul_template']['start_script_file']
file "#{consul_template_template_path}/#{jenkins_start_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    # Generate this file when one of the flag files changes. The files are all empty
    # but they only exist once one of the previous configurations has been executed
    # Active directory is: {{ file "#{flag_groovy_ad}" }}
    # The configuration is: {{ file "#{flag_config}" }}
    # The location configuration is: {{ file "#{flag_location_config}" }}
    # The email configuration is: {{ file "#{flag_mailer_config}" }}
    # The vault configuration is: {{ file "#{flag_vault_config}" }}
    # The RabbitMQ configuration is: {{ file "#{flag_rabbitmq_config}" }}
    # The credentials configuration is: {{ file "#{flag_credentials_config}" }}
    # The logstash configuration is: {{ file "#{flag_logstash_config}" }}

    if [ "$(cat #{flag_groovy_ad})" = "Initialized" ]; then
      if [ "$(cat #{flag_config})" = "Initialized" ]; then
        if [ "$(cat #{flag_location_config})" = "Initialized" ]; then
          if [ "$(cat #{flag_mailer_config})" = "Initialized" ]; then
            if [ "$(cat #{flag_vault_config})" = "Initialized" ]; then
              if [ "$(cat #{flag_rabbitmq_config})" = "Initialized" ]; then
                if [ "$(cat #{flag_credentials_config})" = "Initialized" ]; then
                  if [ "$(cat #{flag_logstash_config})" = "Initialized" ]; then
                    if ( ! $(systemctl is-enabled --quiet #{jenkins_service_name}) ); then
                      systemctl enable #{jenkins_service_name}

                      while true; do
                        if ( (systemctl is-enabled --quiet #{jenkins_service_name}) ); then
                            break
                        fi

                        sleep 1
                      done
                    fi

                    if ( ! (systemctl is-active --quiet #{jenkins_service_name}) ); then
                      systemctl start #{jenkins_service_name}

                      while true; do
                        if ( (systemctl is-active --quiet #{jenkins_service_name}) ); then
                            break
                        fi

                        sleep 1
                      done
                    else
                      systemctl restart #{jenkins_service_name}
                    fi
                  fi
                fi
              fi
            fi
          fi
        fi
      fi
    fi
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

jenkins_start_script_file = node['jenkins']['consul_template']['start_file']
file "#{consul_template_config_path}/jenkins_start_script.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{jenkins_start_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{jenkins_start_script_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{jenkins_start_script_file}"

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
      perms = 0550

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
  group 'root'
  mode '0550'
  owner 'root'
end
