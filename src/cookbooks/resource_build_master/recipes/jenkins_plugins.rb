# frozen_string_literal: true

#
# Cookbook Name:: resource_build_master
# Recipe:: jenkins_plugins
#
# Copyright 2018, P. van der Velde
#

jenkins_plugins_path = "#{node['jenkins']['path']['home']}/plugins"
directory jenkins_plugins_path do
  action :create
  group node['jenkins']['service_group']
  mode '0770'
  owner node['jenkins']['service_user']
end

plugins = node['jenkins']['plugins']
plugins.each do |name, version|
  remote_file "#{jenkins_plugins_path}/#{name}.hpi" do
    action :create
    group node['jenkins']['service_group']
    mode '0750'
    owner node['jenkins']['service_user']
    source "#{node['jenkins']['url']['plugins']}/#{name}/#{version}/#{name}.hpi"
  end
end

# Create this file manually because for some reason berkshelf throughs a hissy when we add this file to the
# cookbook files. Probably because the name is quite long
file "#{node['jenkins']['path']['home']}/org.jenkinsci.plugins.workflow.flow.GlobalDefaultFlowDurabilityLevel.xml" do
  action :create
  content <<~XML
    <?xml version='1.1' encoding='UTF-8'?>
    <org.jenkinsci.plugins.workflow.flow.GlobalDefaultFlowDurabilityLevel_-DescriptorImpl plugin="workflow-api@2.26">
      <durabilityHint>PERFORMANCE_OPTIMIZED</durabilityHint>
    </org.jenkinsci.plugins.workflow.flow.GlobalDefaultFlowDurabilityLevel_-DescriptorImpl>
  XML
  group node['jenkins']['service_group']
  mode '0750'
  owner node['jenkins']['service_user']
end
