# frozen_string_literal: true

#
# Cookbook Name:: resource_build_master
# Recipe:: default
#
# Copyright 2017, P. van der Velde
#

# Always make sure that apt is up to date
apt_update 'update' do
  action :update
end

#
# Include the local recipes
#

include_recipe 'resource_build_master::firewall'

include_recipe 'resource_build_master::meta'
include_recipe 'resource_build_master::provisioning'

include_recipe 'resource_build_master::java'
include_recipe 'resource_build_master::jenkins'
