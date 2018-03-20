# frozen_string_literal: true

require 'spec_helper'

nexus_management_port = 8081
nexus_proxy_path = '/artefacts'

describe 'resource_build_master::jenkins' do
  context 'creates the nexus user' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }
  end

  context 'creates the file system mounts' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates and mounts the nexus_scratch file system at /srv/nexus/blob/scratch' do
      expect(chef_run).to create_directory('/srv/nexus/blob/scratch').with(
        group: 'nexus',
        mode: '777',
        owner: 'nexus'
      )
    end
  end
end
