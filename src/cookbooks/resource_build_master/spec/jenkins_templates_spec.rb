# frozen_string_literal: true

require 'spec_helper'

flag_content = <<~CONF
  NotInitialized
CONF

describe 'resource_build_master::jenkins_templates' do
  context 'adds the consul-template files for the groovy AD script' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates flag files for the jenkins configuration' do
      expect(chef_run).to create_file('/var/log/jenkins_groovy_ad.log')
        .with_content(flag_content)
    end

    jenkins_groovy_ad_script_template_content = <<~CONF
      #!/bin/sh

      {{ if keyExists "config/environment/directory/initialized" }}
      FLAG=$(cat /var/log/jenkins_groovy_ad.log)
      if [ "$FLAG" = "NotInitialized" ]; then
          echo "Write the jenkins active directory groovy script ..."
          cat <<EOT > /var/jenkins/init.groovy.d/p050.activedirectory.groovy
      import hudson.plugins.active_directory.*
      import jenkins.model.*

      def instance = Jenkins.getInstance();
      def ActiveDirectoryDomain adDomain = new ActiveDirectoryDomain("{{ key "config/environment/directory/name" }}");
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
        "{{ key "config/environment/directory/users/bindcn" }}",

        // bindPassword
        {{ with secret "secret/environment/directory/users/bind" }}{{ if .Data.password }}"{{ .Data.password }}"{{ end }}{{ end }},

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
        false,

        // tlsConfiguration
        null,

        // internalUsersDatabase: Note that this user name should be updated if the admin user name changes
        "admin")

      instance.setSecurityRealm(securityRealm)
      instance.save()
      EOT
          if ( ! (systemctl is-active --quiet jenkins) ); then
              systemctl reload jenkins
          fi

          echo "Initialized" > /var/log/jenkins_groovy_ad.log
      fi

      {{ else }}
      echo "Not all Consul K-V values are available. Will not start Jenkins."
      {{ end }}
    CONF
    it 'creates jenkins groovy Active Directory script template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/jenkins_groovy_ad.ctmpl')
        .with_content(jenkins_groovy_ad_script_template_content)
    end

    consul_template_jenkins_groovy_ad_configuration_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/jenkins_groovy_ad.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/jenkins_groovy_ad.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "sh /tmp/jenkins_groovy_ad.sh"

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
    CONF
    it 'creates jenkins_configuration.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/jenkins_groovy_ad.hcl')
        .with_content(consul_template_jenkins_groovy_ad_configuration_content)
    end
  end

  context 'adds the consul-template files for the jenkins configuration' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates flag files for the jenkins configuration' do
      expect(chef_run).to create_file('/var/log/jenkins_config.log')
        .with_content(flag_content)
    end

    jenkins_configuration_script_template_content = <<~CONF
      #!/bin/sh

      {{ if keyExists "config/services/consul/datacenter" }}
      {{ if keyExists "config/services/consul/domain" }}
      FLAG=$(cat /var/log/jenkins_config.log)
      if [ "$FLAG" = "NotInitialized" ]; then
          echo "Write the jenkins configuration ..."
          cat <<EOT > /var/jenkins/config.xml
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
              <assignedSIDs/>
            </role>
          </roleMap>
          <roleMap type="slaveRoles">
            <role name="agent.connect" pattern=".*">
              <permissions>
                <permission>hudson.model.Computer.Connect</permission>
                <permission>hudson.model.Computer.Disconnect</permission>
              </permissions>
              <assignedSIDs/>
            </role>
            <role name="agent.build" pattern=".*">
              <permissions>
                <permission>hudson.model.Computer.Build</permission>
              </permissions>
              <assignedSIDs/>
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
        <slaveAgentPort>5000</slaveAgentPort>
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
        <workspaceDir>/tmp/jenkins/workspace/${ITEM_FULL_NAME}</workspaceDir>
        <!--
              The global directory where the build data (logs etc.) will be kept.
          -->
        <buildsDir>/var/builds/${ITEM_FULL_NAME}</buildsDir>

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

        <!-- VM AND CONTAINER CLOUDS -->
        <clouds>
          <org.jenkinsci.plugins.nomad.NomadCloud plugin="nomad@0.4">
            <name>Nomad</name>
            <instanceCap>2147483647</instanceCap>
            <templates>
            </templates>
            <name defined-in="org.jenkinsci.plugins.nomad.NomadCloud">Nomad</name>
            <nomadUrl>http://{{ key "config/services/jobs/protocols/http/host" }}.service.{{ key "config/services/consul/domain" }}:{{ key "config/services/jobs/protocols/http/port" }}</nomadUrl>
            <jenkinsUrl>http://active.builds.service.{{ key "config/services/consul/domain" }}:8080/builds</jenkinsUrl>
            <slaveUrl>http://active.builds.service.{{ key "config/services/consul/domain" }}:8080/builds/jnlpJars/slave.jar</slaveUrl>
            <nomad>
              <nomadApi>http://{{ key "config/services/jobs/protocols/http/host" }}.service.{{ key "config/services/consul/domain" }}:{{ key "config/services/jobs/protocols/http/port" }}</nomadApi>
            </nomad>
            <pending>0</pending>
          </org.jenkinsci.plugins.nomad.NomadCloud>
        </clouds>
      </hudson>
      EOT

          if ( ! (systemctl is-active --quiet jenkins) ); then
              systemctl reload jenkins
          fi

          echo "Initialized" > /var/log/jenkins_config.log
      fi

      {{ else }}
      echo "Not all Consul K-V values are available. Will not start Jenkins."
      {{ end }}
      {{ else }}
      echo "Not all Consul K-V values are available. Will not start Jenkins."
      {{ end }}
    CONF
    it 'creates jenkins configuration script template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/jenkins_configuration.ctmpl')
        .with_content(jenkins_configuration_script_template_content)
    end

    consul_template_jenkins_configuration_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/jenkins_configuration.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/jenkins_configuration.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "sh /tmp/jenkins_configuration.sh"

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
    CONF
    it 'creates jenkins_configuration.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/jenkins_configuration.hcl')
        .with_content(consul_template_jenkins_configuration_content)
    end
  end

  context 'adds the consul-template files for the jenkins location configuration' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates flag files for the jenkins location configuration' do
      expect(chef_run).to create_file('/var/log/jenkins_location_config.log')
        .with_content(flag_content)
    end

    jenkins_location_configuration_script_template_content = <<~CONF
      #!/bin/sh

      {{ if keyExists "config/environment/mail/suffix" }}
      {{ if keyExists "config/services/builds/url/proxy" }}
      FLAG=$(cat /var/log/jenkins_location_config.log)
      if [ "$FLAG" = "NotInitialized" ]; then
          echo "Write the jenkins vault configuration ..."
          cat <<EOT > /var/jenkins/jenkins.model.JenkinsLocationConfiguration.xml
      <?xml version='1.0' encoding='UTF-8'?>
      <jenkins.model.JenkinsLocationConfiguration>
        <adminAddress>Builds &lt;builds@{{ key "config/environment/mail/suffix" }}&gt;</adminAddress>
        <jenkinsUrl>{{ key "config/services/builds/url/proxy" }}</jenkinsUrl>
      </jenkins.model.JenkinsLocationConfiguration>
      EOT

          if ( ! (systemctl is-active --quiet jenkins) ); then
              systemctl reload jenkins
          fi

          echo "Initialized" > /var/log/jenkins_location_config.log
      fi

      {{ else }}
      echo "Not all Consul K-V values are available. Will not start Jenkins."
      {{ end }}
      {{ else }}
      echo "Not all Consul K-V values are available. Will not start Jenkins."
      {{ end }}
    CONF
    it 'creates jenkins location configuration script template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/jenkins_location_configuration.ctmpl')
        .with_content(jenkins_location_configuration_script_template_content)
    end

    consul_template_jenkins_location_configuration_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/jenkins_location_configuration.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/jenkins_location_configuration.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "sh /tmp/jenkins_location_configuration.sh"

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
    CONF
    it 'creates jenkins_location_configuration.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/jenkins_location_configuration.hcl')
        .with_content(consul_template_jenkins_location_configuration_content)
    end
  end

  context 'adds the consul-template files for the jenkins mailer configuration' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates flag files for the jenkins mailer configuration' do
      expect(chef_run).to create_file('/var/log/jenkins_mailer_config.log')
        .with_content(flag_content)
    end

    jenkins_mailer_configuration_script_template_content = <<~CONF
      #!/bin/sh

      {{ if keyExists "config/environment/mail/smtp/host" }}
      {{ if keyExists "config/environment/mail/suffix" }}
      {{ if keyExists "config/services/builds/url/proxy" }}
      FLAG=$(cat /var/log/jenkins_mailer_config.log)
      if [ "$FLAG" = "NotInitialized" ]; then
          echo "Write the jenkins vault configuration ..."
          cat <<EOT > /var/jenkins/hudson.tasks.Mailer.xml
      <?xml version='1.0' encoding='UTF-8'?>
      <hudson.tasks.Mailer_-DescriptorImpl plugin="mailer@1.19">
        <defaultSuffix>@{{ key "config/environment/mail/suffix" }}</defaultSuffix>
        <hudsonUrl>{{ key "config/services/builds/url/proxy" }}</hudsonUrl>
        <smtpHost>{{ key "config/environment/mail/smtp/host" }}</smtpHost>
        <useSsl>false</useSsl>
        <charset>UTF-8</charset>
      </hudson.tasks.Mailer_-DescriptorImpl>
      EOT

          if ( ! (systemctl is-active --quiet jenkins) ); then
              systemctl reload jenkins
          fi

          echo "Initialized" > /var/log/jenkins_mailer_config.log
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
    it 'creates jenkins mailer configuration script template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/jenkins_mailer_configuration.ctmpl')
        .with_content(jenkins_mailer_configuration_script_template_content)
    end

    consul_template_jenkins_mailer_configuration_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/jenkins_mailer_configuration.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/jenkins_mailer_configuration.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "sh /tmp/jenkins_mailer_configuration.sh"

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
    CONF
    it 'creates jenkins_mailer_configuration.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/jenkins_mailer_configuration.hcl')
        .with_content(consul_template_jenkins_mailer_configuration_content)
    end
  end

  context 'adds the consul-template files for the jenkins rabbitmq configuration' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates flag files for the jenkins rabbitmq configuration' do
      expect(chef_run).to create_file('/var/log/jenkins_rabbitmq_config.log')
        .with_content(flag_content)
    end

    jenkins_rabbitmq_configuration_script_template_content = <<~CONF
      #!/bin/sh

      {{ if keyExists "config/services/consul/datacenter" }}
      {{ if keyExists "config/services/consul/domain" }}
      {{ if keyExists "config/services/queue/protocols/amqp/host" }}
      FLAG=$(cat /var/log/jenkins_rabbitmq_config.log)
      if [ "$FLAG" = "NotInitialized" ]; then
          echo "Write the jenkins rabbitmq configuration ..."
          cat <<EOT > /var/jenkins/org.jenkinsci.plugins.rabbitmqconsumer.GlobalRabbitmqConfiguration.xml
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
      {{ with secret "rabbitmq/creds/builds.queue.reader" }}
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

          if ( ! (systemctl is-active --quiet jenkins) ); then
              systemctl reload jenkins
          fi

          echo "Initialized" > /var/log/jenkins_rabbitmq_config.log
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
    it 'creates jenkins rabbitmq configuration script template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/jenkins_rabbitmq_configuration.ctmpl')
        .with_content(jenkins_rabbitmq_configuration_script_template_content)
    end

    consul_template_jenkins_rabbitmq_configuration_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/jenkins_rabbitmq_configuration.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/jenkins_rabbitmq_configuration.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "sh /tmp/jenkins_rabbitmq_configuration.sh"

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
    CONF
    it 'creates jenkins_rabbitmq_configuration.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/jenkins_rabbitmq_configuration.hcl')
        .with_content(consul_template_jenkins_rabbitmq_configuration_content)
    end
  end

  context 'adds the consul-template files for the jenkins vault configuration' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates flag files for the jenkins vault configuration' do
      expect(chef_run).to create_file('/var/log/jenkins_vault_config.log')
        .with_content(flag_content)
    end

    jenkins_vault_configuration_script_template_content = <<~CONF
      #!/bin/sh

      {{ if keyExists "config/services/consul/datacenter" }}
      {{ if keyExists "config/services/consul/domain" }}
      FLAG=$(cat /var/log/jenkins_vault_config.log)
      if [ "$FLAG" = "NotInitialized" ]; then
          echo "Write the jenkins vault configuration ..."
          cat <<EOT > /var/jenkins/com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration.xml
      <?xml version='1.0' encoding='UTF-8'?>
      <com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration plugin="hashicorp-vault-plugin@2.1.0">
      <configuration>
          <vaultUrl>http://secrets.service.{{ key "config/services/consul/domain" }}</vaultUrl>
          <vaultCredentialId>global.vault.approle</vaultCredentialId>
      </configuration>
      </com.datapipe.jenkins.vault.configuration.GlobalVaultConfiguration>
      EOT

          if ( ! (systemctl is-active --quiet jenkins) ); then
              systemctl reload jenkins
          fi

          echo "Initialized" > /var/log/jenkins_vault_config.log
      fi

      {{ else }}
      echo "Not all Consul K-V values are available. Will not start Jenkins."
      {{ end }}
      {{ else }}
      echo "Not all Consul K-V values are available. Will not start Jenkins."
      {{ end }}
    CONF
    it 'creates jenkins vault configuration script template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/jenkins_vault_configuration.ctmpl')
        .with_content(jenkins_vault_configuration_script_template_content)
    end

    consul_template_jenkins_vault_configuration_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/jenkins_vault_configuration.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/jenkins_vault_configuration.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "sh /tmp/jenkins_vault_configuration.sh"

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
    CONF
    it 'creates jenkins_vault_configuration.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/jenkins_vault_configuration.hcl')
        .with_content(consul_template_jenkins_vault_configuration_content)
    end
  end

  context 'adds the consul-template files for the jenkins start script' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    jenkins_start_script_template_content = <<~CONF
      #!/bin/sh

      # Generate this file when one of the flag files changes. The files are all empty
      # but they only exist once one of the previous configurations has been executed
      # {{ file "/var/log/jenkins_groovy_ad.log" }}
      # {{ file "/var/log/jenkins_config.log" }}
      # {{ file "/var/log/jenkins_location_config.log" }}
      # {{ file "/var/log/jenkins_mailer_config.log" }}
      # {{ file "/var/log/jenkins_rabbitmq_config.log" }}
      # {{ file "/var/log/jenkins_vault_config.log" }}

      if [ "$(cat /var/log/jenkins_groovy_ad.log)" = "Initialized" ]; then
        if [ "$(cat /var/log/jenkins_config.log)" = "Initialized" ]; then
          if [ "$(cat /var/log/jenkins_location_config.log)" = "Initialized" ]; then
            if [ "$(cat /var/log/jenkins_mailer_config.log)" = "Initialized" ]; then
              if [ "$(cat /var/log/jenkins_rabbitmq_config.log)" = "Initialized" ]; then
                if [ "$(cat /var/log/jenkins_vault_config.log)" = "Initialized" ]; then
                  if ( ! $(systemctl is-enabled --quiet jenkins) ); then
                    systemctl enable jenkins

                    while true; do
                      if ( (systemctl is-enabled --quiet jenkins) ); then
                          break
                      fi

                      sleep 1
                    done
                  fi

                  if ( ! (systemctl is-active --quiet jenkins) ); then
                    systemctl start jenkins

                    while true; do
                      if ( (systemctl is-active --quiet jenkins) ); then
                          break
                      fi

                      sleep 1
                    done
                  else
                    systemctl reload jenkins
                  fi
                fi
              fi
            fi
          fi
        fi
      fi
    CONF
    it 'creates jenkins start script template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/jenkins_start_script.ctmpl')
        .with_content(jenkins_start_script_template_content)
    end

    consul_template_jenkins_start_script_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/jenkins_start_script.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/jenkins_start_script.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "sh /tmp/jenkins_start_script.sh"

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
    CONF
    it 'creates jenkins_start_script.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/jenkins_start_script.hcl')
        .with_content(consul_template_jenkins_start_script_content)
    end
  end
end
