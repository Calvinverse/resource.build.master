# frozen_string_literal: true

#
# CONSULTEMPLATE
#

default['consul_template']['config_path'] = '/etc/consul-template.d/conf'
default['consul_template']['template_path'] = '/etc/consul-template.d/templates'

#
# FIREWALL
#

# Allow communication on the loopback address (127.0.0.1 and ::1)
default['firewall']['allow_loopback'] = true

# Do not allow MOSH connections
default['firewall']['allow_mosh'] = false

# Do not allow WinRM (which wouldn't work on Linux anyway, but close the ports just to be sure)
default['firewall']['allow_winrm'] = false

# No communication via IPv6 at all
default['firewall']['ipv6_enabled'] = false

#
# JAVA
#

default['java']['jdk_version'] = '8'
default['java']['install_flavor'] = 'openjdk'
default['java']['install_type'] = 'jdk'

#
# JENKINS
#

default['jenkins']['path']['build_data'] = '/srv/builds'
default['jenkins']['path']['casc'] = '/etc/jenkins.d/casc'
default['jenkins']['path']['environment_file'] = '/etc/jenkins_environment'
default['jenkins']['path']['home'] = '/var/jenkins'
default['jenkins']['path']['war'] = '/usr/local/jenkins'
default['jenkins']['path']['war_file'] = "#{node['jenkins']['path']['war']}/jenkins.war"
default['jenkins']['path']['pid_file'] = "#{node['jenkins']['path']['war']}/jenkins_pid"

default['jenkins']['consul']['service_name'] = 'builds'
default['jenkins']['proxy_path'] = 'builds'

default['jenkins']['port']['http'] = 8080
default['jenkins']['port']['slave'] = 5000

default['jenkins']['service_name'] = 'jenkins'

default['jenkins']['service_user'] = 'jenkins'
default['jenkins']['service_group'] = 'jenkins'

default['jenkins']['consul_template']['config_script_file'] = 'jenkins_configuration.ctmpl'
default['jenkins']['consul_template']['config_file'] = '/tmp/jenkins_configuration.sh'

default['jenkins']['consul_template']['credentials_config_script_file'] = 'jenkins_casc_credentials.ctmpl'
default['jenkins']['consul_template']['credentials_file'] = '/tmp/jenkins_casc_credentials.sh'

default['jenkins']['consul_template']['groovy_ad_script_file'] = 'jenkins_groovy_ad.ctmpl'
default['jenkins']['consul_template']['groovy_ad_file'] = '/tmp/jenkins_groovy_ad.sh'

default['jenkins']['consul_template']['location_config_script_file'] = 'jenkins_location_configuration.ctmpl'
default['jenkins']['consul_template']['location_config_file'] = '/tmp/jenkins_location_configuration.sh'

default['jenkins']['consul_template']['logstash_config_script_file'] = 'jenkins_casc_logstash.ctmpl'
default['jenkins']['consul_template']['logstash_file'] = '/tmp/jenkins_casc_logstash.sh'

default['jenkins']['consul_template']['mailer_config_script_file'] = 'jenkins_mailer_configuration.ctmpl'
default['jenkins']['consul_template']['mailer_config_file'] = '/tmp/jenkins_mailer_configuration.sh'

default['jenkins']['consul_template']['rabbitmq_config_script_file'] = 'jenkins_casc_rabbitmq.ctmpl'
default['jenkins']['consul_template']['rabbitmq_config_file'] = '/tmp/jenkins_casc_rabbitmq.sh'

default['jenkins']['consul_template']['start_script_file'] = 'jenkins_start_script.ctmpl'
default['jenkins']['consul_template']['start_file'] = '/tmp/jenkins_start_script.sh'

default['jenkins']['consul_template']['vault_config_script_file'] = 'jenkins_vault_configuration.ctmpl'
default['jenkins']['consul_template']['vault_config_file'] = '/tmp/jenkins_vault_configuration.sh'

default['jenkins']['version'] = '2.190.3'
default['jenkins']['checksum'] = '79C2042B30AD71DC9CF17A5877F64EAED405FA03E24E002CA60F8DB73B7AD490'
default['jenkins']['url']['war'] = "https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/#{node['jenkins']['version']}/jenkins-war-#{node['jenkins']['version']}.war"
default['jenkins']['url']['plugins'] = 'https://updates.jenkins.io/download/plugins'

#
# JOLOKIA
#

default['jolokia']['path']['jar'] = '/usr/local/jolokia'
default['jolokia']['path']['jar_file'] = "#{node['jolokia']['path']['jar']}/jolokia.jar"

default['jolokia']['agent']['context'] = 'jolokia' # Set this to default because the runtime gets angry otherwise
default['jolokia']['agent']['host'] = '127.0.0.1' # Linux prefers going to IPv6, but Jolokia hates IPv6
default['jolokia']['agent']['port'] = 8090

default['jolokia']['telegraf']['consul_template_inputs_file'] = 'telegraf_jolokia_inputs.ctmpl'

default['jolokia']['version'] = '1.6.2'
default['jolokia']['checksum'] = '95EEF794790AA98CFA050BDE4EC67A4E42C2519E130E5E44CE40BF124584F323'
default['jolokia']['url']['jar'] = "http://search.maven.org/remotecontent?filepath=org/jolokia/jolokia-jvm/#{node['jolokia']['version']}/jolokia-jvm-#{node['jolokia']['version']}-agent.jar"

#
# TELEGRAF
#

default['telegraf']['service_user'] = 'telegraf'
default['telegraf']['service_group'] = 'telegraf'
default['telegraf']['config_directory'] = '/etc/telegraf/telegraf.d'
