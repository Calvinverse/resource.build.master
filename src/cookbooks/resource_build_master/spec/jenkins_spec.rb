# frozen_string_literal: true

require 'spec_helper'

describe 'resource_build_master::jenkins' do
  context 'creates the jenkins environment file' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    jenkins_environment_content = <<~TXT
      JENKINS_HOME=/var/jenkins
      CASC_JENKINS_CONFIG=/etc/jenkins.d/casc
    TXT
    it 'creates the /etc/jenkins_environment file' do
      expect(chef_run).to create_file('/etc/jenkins_environment')
        .with_content(jenkins_environment_content)
        .with(
          group: 'jenkins',
          owner: 'jenkins',
          mode: '0550'
        )
    end
  end

  context 'installs jenkins' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'copies the configuration files from the cookbook' do
      expect(chef_run).to create_remote_directory('/var/jenkins')
        .with(
          source: 'jenkins'
        )
    end

    it 'updates the permissions on the job directory' do
      expect(chef_run).to create_directory('/var/jenkins/jobs')
        .with(
          group: 'jenkins',
          owner: 'jenkins',
          mode: '0750'
        )
    end

    it 'creates the jenkins install directory' do
      expect(chef_run).to create_directory('/usr/local/jenkins')
        .with(
          group: 'jenkins',
          owner: 'jenkins',
          mode: '0770'
        )
    end

    it 'installs the jenkins war file' do
      expect(chef_run).to create_remote_file('/usr/local/jenkins/jenkins.war')
        .with(
          source: 'https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/2.138.2/jenkins-war-2.138.2.war',
          group: 'jenkins',
          owner: 'jenkins',
          mode: '0550'
        )
    end

    it 'creates the metrics configuration file' do
      jenkins_metrics_config_content = <<~XML
        <?xml version='1.0' encoding='UTF-8'?>
        <jenkins.metrics.api.MetricsAccessKey_-DescriptorImpl plugin="metrics">
          <accessKeys>
            <jenkins.metrics.api.MetricsAccessKey>
              <key>13f716ae-9fcd-409a-9ca5-12461ab53405</key>
              <description>Consul ping check</description>
              <canPing>true</canPing>
              <canThreadDump>false</canThreadDump>
              <canHealthCheck>false</canHealthCheck>
              <canMetrics>false</canMetrics>
            </jenkins.metrics.api.MetricsAccessKey>
          </accessKeys>
        </jenkins.metrics.api.MetricsAccessKey_-DescriptorImpl>
      XML
      expect(chef_run).to create_file('/var/jenkins/jenkins.metrics.api.MetricsAccessKey.xml')
        .with_content(jenkins_metrics_config_content)
        .with(
          group: 'jenkins',
          owner: 'jenkins',
          mode: '0750'
        )
    end

    it 'creates the jenkins configuration-as-code directory' do
      expect(chef_run).to create_remote_directory('/etc/jenkins.d/casc')
    end
  end

  context 'configures the firewall for jenkins' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Jenkins HTTP port' do
      expect(chef_run).to create_firewall_rule('jenkins-http').with(
        command: :allow,
        dest_port: 8080,
        direction: :in
      )
    end

    it 'opens the Jenkins slave port' do
      expect(chef_run).to create_firewall_rule('jenkins-slave').with(
        command: :allow,
        dest_port: 5000,
        direction: :in
      )
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_jenkins_config_content = <<~JSON
      {
        "service": {
          "checks": [
            {
              "id": "jenkins_ping",
              "name": "Jenkins HTTP ping",
              "http": "http://localhost:8080/builds/metrics/13f716ae-9fcd-409a-9ca5-12461ab53405/ping",
              "interval": "15s"
            }
          ],
          "enable_tag_override": false,
          "id": "jenkins",
          "name": "builds",
          "port": 8080,
          "tags": [
            "active",
            "edgeproxyprefix-/builds"
          ]
        }
      }
    JSON
    it 'creates the /etc/consul/conf.d/jenkins-http.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/jenkins-http.json')
        .with_content(consul_jenkins_config_content)
    end
  end
end
