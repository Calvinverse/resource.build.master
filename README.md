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

## Build, test and deploy

The build process follows the standard procedure for building Calvinverse images.

## Deploy

### Environment

Prior to the provisioning of a new Jenkins host the following information should be available in
the environment in which the Jenkins instance will be created.

* **Active Directory**
  * Create the AD group for the build agents accounts that are allowed to connect Jenkins agents
    to the Jenkins controller
* **Build agents**
  * Make sure the build agents are looking for the host by the correct Consul DNS name

Make sure that the following keys exist in the Consul key-value store

* `config/environment/directory/endpoints/hosts` - Add an entry for each AD host where the host
  name is the key and the IP address is the value
* `config/environment/directory/name` - The name of the Active Directory.
* `config/environment/directory/query/groups/builds/administrators` - The name of the AD group
  that contains the users who should be given administrator access to Jenkins
* `config/environment/directory/query/groups/builds/agent` - The name of the AD group that contains
  the users who should be allowed to connect Jenkins agents to the controller
* `config/environment/directory/users/bindcn` - The fully qualified name of the user that can
  be used to perform Active Directory searches.
* `config/environment/mail/smtp/host` - The host name of the SMTP server
* `config/environment/mail/suffix` - The email suffix for emails send to the local domain.
* `config/projects` - Add the user name of the user which is allowed to access the source code in
  a project as `config/projects/<COLLECTION>/<PROJECT>/user`
* `config/services/builds/url/proxy` - The proxy address for the Jenkins UI
* `config/services/consul/domain` - The consul domain.
* `config/services/queue/builds/vhost` - The name of the [vhost](https://www.rabbitmq.com/vhosts.html)
  that will contain the build trigger queues
* `config/services/queue/protocols/amqp/host` - The host name of the AMQP endpoint on the queue service
* `config/services/queue/protocols/amqp/port` - The port of the AMQP endpoint on the queue service
* `config/services/secrets/protocols/http/host` - The host name of the HTTP endpoint on the secrets
  service
* `config/services/secrets/protocols/http/port` - The port of the HTTP endpoint on the secrets service

Finally add the secrets to Vault at the following paths

* `secret/environment/directory/users/bind` - Add the `password` of the bindcn user
* `secret/services/queue/users/build`  - Add the `username` and `password` of a user who has
  access to the `vhost.build.trigger` vhost in RabbitMQ in the correct environment. It is
  recommended that a new user is created for this purpose with a generated password, e.g.
  a GUID will work
* For each project that should be accessed add the `password` of the AD service user who can
  access this project under the `secret/projects/<PROJECT_COLLECTION>/<PROJECT>/user` key

### Image provisioning

Once the environment is configured take the following steps to provision the Jenkins image

* Download the new image to a Hyper-V hosts.
* Create a VM that points to the image VHDX file with the following settings
  * Name: `<Environment>_<ResourceName>-<Number>`
  * Generation: 2
  * RAM: 6144 Mb. Do *not* use dynamic memory
  * Network: VM
  * Hard disk: Use existing. Copy the path to the VHDX file
* Update the VM settings:
  * Enable secure boot. Use the Microsoft UEFI Certificate Authority
  * Set the number of CPUs to 2
  * Attach the additional HDD
  * Attach a DVD image that points to an ISO file containing the settings for the environment. These
    are normally found in the output of the
    [Calvinverse.Infrastructure](https://github.com/Calvinverse/calvinverse.infrastructure)
    repository. Pick the correct ISO for the task, in this case the `Linux Consul Client` image
  * Disable checkpoints
  * Set the VM to always start
  * Set the VM to shut down on stop
* Stop the existing Jenkins
  * Set jenkins to not accept any more builds
  * Wait for the the running builds to complete
  * Shut down the jenkins service
    * On windows
      * Remote desktop into the machine
      * Stop the jenkins service via the services control panel
      * Stop consul by issuing the `c:\ops\consul\bin\consul.exe leave` command from a command line window
    * On linux
      * SSH into the host
      * Disconnect jenkins by stopping the jenkins service: `sudo systemctl stop jenkins`
      * Issue the `consul leave` command
      * Shut the machine down with the `sudo shutdown now` command
* Start the VM, it should automatically connect to the correct environment once it has provisioned
* Provide the machine with credentials for Consul-Template so that it can configure the Jenkins controller
  with the appropriate secrets
* Once the machine has connected to the Jenkins controller the old VM can be removed
  * On windows
    * Remote desktop in to the machine
    * If the machine should be returned to ICT then also
      * Set the consul service to `disabled`
      * Set the jenkins service to `disabled`
      * Set the telegraf service to `disabled`
    * Shut the machine down
    * Delete the VM if DevInfrastructure owns it or return it to ICT
  * On linux
    * SSH into the host
    * Shut the machine down with the `sudo shutdown now` command
    * Once the machine has stopped, delete it

## Usage

Once the resource is started and provided with the correct permissions to retrieve information
from [Vault](https://vaultproject.io) it will automatically become the active Jenkins server. The
UI for Jenkins can be found via the proxy page on `http://<PROXY_HOST_NAME>/builds`.
