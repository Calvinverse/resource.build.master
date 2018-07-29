# frozen_string_literal: true

require 'spec_helper'

describe 'resource_build_master::jenkins_plugins' do
  context 'installs the plugins' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }
    let(:node) { chef_run.node }

    it 'creates the plugins directory' do
      expect(chef_run).to create_directory('/var/jenkins/plugins')
    end

    it 'installs the plugins' do
      plugins = node['jenkins']['plugins']
      plugins.each do |name, version|
        expect(chef_run).to create_remote_file("/var/jenkins/plugins/#{name}.hpi")
          .with(
            source: "https://updates.jenkins.io/download/plugins/#{name}/#{version}/#{name}.hpi",
            group: 'jenkins',
            owner: 'jenkins',
            mode: '0750'
          )
      end
    end
  end
end
