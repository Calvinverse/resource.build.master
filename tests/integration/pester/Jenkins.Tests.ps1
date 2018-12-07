Describe 'The jenkins application' {
    Context 'is installed' {
        It 'with binaries in /usr/local/jenkins' {
            '/usr/local/jenkins/jenkins.war' | Should Exist
        }

        It 'with configuration in /var/jenkins' {
            '/var/jenkins' | Should Exist
        }
    }

    Context 'has been daemonized' {
        $serviceConfigurationPath = '/etc/systemd/system/jenkins.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
               $false | Should Be $true
            }
        }

        $expectedContent = @'
[Service]
Type = forking
PIDFile = /usr/local/jenkins/jenkins_pid
ExecStart = /usr/local/jenkins/run_jenkins.sh
ExecReload = /usr/bin/curl http://localhost:8080/builds/reload
ExecStop = /usr/bin/curl http://localhost:8080/builds/safeExit
Restart = on-failure
User = jenkins
EnvironmentFile = /etc/jenkins_environment

[Unit]
Description = Jenkins CI system
Documentation = https://jenkins.io
Requires = network-online.target
After = network-online.target

[Install]
WantedBy = multi-user.target

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status jenkins
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'jenkins.service - jenkins'
        }

        It 'that is not enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\sdisabled;.*\)'

        }

        It 'and is not running' {
            $systemctlOutput[2] | Should Match 'Active:\sinactive\s\(dead\).*'
        }
    }
}
