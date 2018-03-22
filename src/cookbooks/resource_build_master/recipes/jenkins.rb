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
jenkins_environment_file = node['jenkins']['path']['environment_file']
file jenkins_environment_file do
  action :create
  content <<~TXT
    JENKINS_HOME=#{jenkins_home}
  TXT
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

consul_metrics_key = '13f716ae-9fcd-409a-9ca5-12461ab53405'
file "#{jenkins_home}/jenkins.metrics.api.MetricsAccessKey.xml" do
  action :create
  content <<~XML
    <?xml version='1.0' encoding='UTF-8'?>
    <jenkins.metrics.api.MetricsAccessKey_-DescriptorImpl plugin="metrics">
      <accessKeys>
        <jenkins.metrics.api.MetricsAccessKey>
          <key>#{consul_metrics_key}</key>
          <description>Consul ping check</description>
          <canPing>true</canPing>
          <canThreadDump>false</canThreadDump>
          <canHealthCheck>false</canHealthCheck>
          <canMetrics>false</canMetrics>
        </jenkins.metrics.api.MetricsAccessKey>
      </accessKeys>
    </jenkins.metrics.api.MetricsAccessKey_-DescriptorImpl>
  XML
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
# CONSUL FILES
#

# This assumes the health user is called 'health' and the password is 'health'
consul_service_name = node['jenkins']['consul']['service_name']
proxy_path = node['jenkins']['proxy_path']
file '/etc/consul/conf.d/jenkins-http.json' do
  action :create
  content <<~JSON
    {
      "service": {
        "checks": [
          {
            "id": "jenkins_ping",
            "name": "Jenkins HTTP ping",
            "http": "http://localhost:#{jenkins_http_port}/#{proxy_path}/metrics/#{consul_metrics_key}/ping",
            "interval": "15s"
          }
        ],
        "enableTagOverride": true,
        "id": "jenkins",
        "name": "#{consul_service_name}",
        "port": #{jenkins_http_port},
        "tags": [
          "inactive",
          "edgeproxyprefix-/#{proxy_path}"
        ]
      }
    }
  JSON
end
