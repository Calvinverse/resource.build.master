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

default['java']['jdk_version'] = '9'
default['java']['install_flavor'] = 'openjdk'
default['java']['accept_license_agreement'] = true

default['jenkins']['path']['home'] = '/var/jenkins'
default['jenkins']['path']['war'] = '/usr/local/jenkins/jenkins.war'

default['jenkins']['proxy_path'] = 'builds'

default['jenkins']['port']['http'] = 8080
default['jenkins']['port']['slave'] = 5000

default['jenkins']['service_name'] = 'jenkins'

default['jenkins']['service_user'] = 'jenkins'
default['jenkins']['service_group'] = 'jenkins'

#
# JENKINS
#

default['jenkins']['version'] = '2.107.1'
default['jenkins']['checksum'] = '8bc54e7005c1e4ff7d68a7cd724b65cddb9d8e09ad81c89e01f6819254f97a86'
default['jenkins']['url'] = "https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/#{node['jenkins']['version']}/jenkins-war-#{node['jenkins']['version']}.war"

#
# TELEGRAF
#

default['telegraf']['config_directory'] = '/etc/telegraf/telegraf.d'
