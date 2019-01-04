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
# JENKINS
#

default['jenkins']['path']['build_data'] = '/var/builds'
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

default['jenkins']['consul_template']['mailer_config_script_file'] = 'jenkins_mailer_configuration.ctmpl'
default['jenkins']['consul_template']['mailer_config_file'] = '/tmp/jenkins_mailer_configuration.sh'

default['jenkins']['consul_template']['rabbitmq_config_script_file'] = 'jenkins_rabbitmq_configuration.ctmpl'
default['jenkins']['consul_template']['rabbitmq_config_file'] = '/tmp/jenkins_rabbitmq_configuration.sh'

default['jenkins']['consul_template']['start_script_file'] = 'jenkins_start_script.ctmpl'
default['jenkins']['consul_template']['start_file'] = '/tmp/jenkins_start_script.sh'

default['jenkins']['consul_template']['vault_config_script_file'] = 'jenkins_vault_configuration.ctmpl'
default['jenkins']['consul_template']['vault_config_file'] = '/tmp/jenkins_vault_configuration.sh'

default['jenkins']['version'] = '2.150.1'
default['jenkins']['checksum'] = '7A38586D5A3A1A83498809A83715728BB2F01B58A7DD3A88366F076EFDAF6669'
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

default['jolokia']['version'] = '1.6.0'
default['jolokia']['checksum'] = '40123D4728CB62BF7D4FD3C8DE7CF3A0F955F89453A645837E611BA8E6924E02'
default['jolokia']['url']['jar'] = "http://search.maven.org/remotecontent?filepath=org/jolokia/jolokia-jvm/#{node['jolokia']['version']}/jolokia-jvm-#{node['jolokia']['version']}-agent.jar"

#
# TELEGRAF
#

default['telegraf']['service_user'] = 'telegraf'
default['telegraf']['service_group'] = 'telegraf'
default['telegraf']['config_directory'] = '/etc/telegraf/telegraf.d'