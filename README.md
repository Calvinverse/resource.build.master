# resource.build.master

This repository contains the source code for the resource.build.master image, the image that
contains an instance of the [Jenkins build server](https://jenkins.io).

## Image

The image is created by using the [Linux base image](https://github.com/Calvinverse/base.linux)
and ammending it using a [Chef](https://www.chef.io/chef/) cookbook which installs the Java
Development Kit, Jenkins and Jolokia.

When the image is created the following additional virtual hard drives are attached:

* For the jenkins build workspaces a dynamic virtual hard drive called `workspace.vhdx` is attached.
  This disk is mounted at the `/srv/builds` path

NOTE: The disks are attached by using a powershell command so that we can attach the disk and then go
find it and set the drive assigment to the unique  signature of the disk. When we deploy the VM we
only use the disks and create a new VM with those disks but that might lead to a different order in
which disks are attached. By having the drive assignments linked to the drive signature we prevent
issues with missing drives

### Contents

* The Java development kit. The version of which is determined by the version of the `java_se`
  cookbook in the `metadata.rb` file.
* The Jenkins WAR file. The version of which is determined by the `default['jenkins']['version']`
  attribute in the `default.rb` attributes file in the cookbook.
* The [Jolokia](https://jolokia.org/) JAR file. The version of which is determined by the
  `default['jolokia']['version']` attribute in the `default.rb` attributes file in the cookbook.
* In addition to Jenkins a large number of plugins are installed. The complete plugin list can be
  found in the `plugins.xml` file in the `src` directory. If the version for a plugin isn't fixed
  then when the `Get-PluginVersions.ps1` script is executed the highest version of that plugin for
  the current version of Jenkins is retrieved. The script updates the `jenkins_plugin_versions.rb`
  attributes file.

### Configuration

* The Jenkins WAR file is installed in the `/usr/local/jenkins` directory
* The Jenkins home directory is `/var/jenkins`
* A number of groovy scripts will be placed in the Jenkins [`init.groovy.d`](https://wiki.jenkins.io/display/JENKINS/Post-initialization+script)
  directory so that they can be executed when Jenkins starts up. The scripts are numbered so that
  they are always executed in the same order.
* The build logs and results are kept in the build directory in `/srv/builds`
* The configuration for the Configuration-as-Code plugin is kept in the `/etc/jenkins.d/casc` directory
* The jenkins UI is available on the localhost on port `8080` and the `builds` subpath
* The jenkins service is started by a script that calculates the maximum amount of memory Jenkins
  can use as 70% of the physical memory that the machine has available. The JVM parameter are set
  to allocate this memory on start-up.

* The Jolokia JAR file is installed in the `/usr/local/jolokia` directory
* The jolokia service publishes data on the `localhost` address only, using port `8090`. This port
  should not be reachable from outside the machine

A service is added to [Consul](https://consul.io) for Jenkins.

* Service: Builds - Tags: http - Port: 8080

The service also adds instructions for the Fabio load balancer so that the Jenkins UI is available
via the proxy.

### Authentication

The Jenkins controller needs a number of credentials. These are:

* Credentials to connect to RabbitMQ. These are obtained via Consul-Template from the
  [Vault](https://vaultproject.io) on the `secret/services/queue/users/build` path. For this case
  currently we do not use the automatically generated RabbitMQ credentials from Vault because that
  requires updating the Jenkins configuration files which requires a restart.
* The credentials which are used to connect to source control are obtained from the Consul K-V, for user
  names, and Vault, for the passwords. These credentials are put in the configuration files for the
  [Configuration-as-Code plugin](https://github.com/jenkinsci/configuration-as-code-plugin) via
  Consul-Template.

### Provisioning

No changes to the provisioning are applied other than the default one for the base image.

### Logs

No additional configuration is applied other than the default one for the base image.

### Metrics

Metrics are collected from Jenkins and the JVM via [Jolokia](https://jolokia.org/) and
[Telegraf](https://www.influxdata.com/time-series-platform/telegraf/).