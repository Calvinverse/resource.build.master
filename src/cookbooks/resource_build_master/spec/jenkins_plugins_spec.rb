# frozen_string_literal: true

require 'spec_helper'

describe 'resource_build_master::jenkins_plugins' do
  context 'installs the plugins' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the plugins directory' do
      expect(chef_run).to create_directory('/var/jenkins/plugins')
    end

    plugins = {
      'active-directory' => '2.6',
      'analysis-core' => '1.95',
      'antisamy-markup-formatter' => '1.5',
      'apache-httpcomponents-client-4-api' => '4.5.3-2.1',
      'build-failure-analyzer' => '1.19.2',
      'build-name-setter' => '1.6.9',
      'build-timeout' => '1.19',
      'build-user-vars-plugin' => '1.5',
      'cloudbees-folder' => '6.4',
      'cobertura' => '1.12',
      'credentials' => '2.1.16',
      'display-url-api' => '2.2.0',
      'durable-task' => '1.22',
      'email-ext' => '2.61',
      'embeddable-build-status' => '1.9',
      'git-client' => '2.7.1',
      'git' => '3.8.0',
      'gravatar' => '2.1',
      'greenballs' => '1.15',
      'hashicorp-vault-plugin' => '2.1.0',
      'icon-shim' => '2.0.3',
      'jackson2-api' => '2.8.11.1',
      'javadoc' => '1.4',
      'job-dsl' => '1.68',
      'junit' => '1.24',
      'jsch' => '0.1.54.2',
      'mailer' => '1.20',
      'matrix-auth' => '2.2',
      'matrix-project' => '1.12',
      'maven-plugin' => '3.1',
      'metrics' => '3.1.2.11',
      'msbuild' => '1.29',
      'nomad' => '0.4',
      'nunit' => '0.23',
      'powershell' => '1.3',
      'PrioritySorter' => '3.6.0',
      'rabbitmq-build-trigger' => '2.5',
      'rabbitmq-consumer' => '2.8',
      'rebuild' => '1.27',
      'resource-disposer' => '0.8',
      'role-strategy' => '2.7.0',
      'scm-api' => '2.2.6',
      'script-security' => '1.42',
      'short-workspace-path' => '0.2',
      'ssh-credentials' => '1.13',
      'structs' => '1.14',
      'swarm' => '3.11',
      'token-macro' => '2.3',
      'violations' => '0.7.11',
      'warnings' => '4.66',
      'workflow-api' => '2.26',
      'workflow-durable-task-step' => '2.19',
      'workflow-job' => '2.17',
      'workflow-scm-step' => '2.6',
      'workflow-step-api' => '2.14',
      'workflow-support' => '2.18',
      'ws-cleanup' => '0.34'
    }
    plugins.each do |name, version|
      it "installs the #{name} plugin" do
        expect(chef_run).to create_remote_file("/var/jenkins/plugins/#{name}.hpi")
          .with(
            source: "https://updates.jenkins.io/download/plugins/#{name}/#{version}/#{name}.hpi"
          )
      end
    end
  end
end
