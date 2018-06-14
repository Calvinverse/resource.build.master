Describe 'The jenkins application' {
    Context 'is installed' {
        It 'with binaries in /usr/local/jenkins' {
            '/usr/local/jenkins/jenkins.war' | Should Exist
        }

        It 'with configuration in /var/jenkins' {
            '/var/jenkins' | Should Exist
            '/var/jenkins/config.xml' | Should Exist
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
Environment="GOMAXPROCS=2" "PATH=/usr/local/bin:/usr/bin:/bin"
ExecStart=/opt/consul/1.0.6/consul agent -config-file=/etc/consul/consul.json -config-dir=/etc/consul/conf.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=TERM
User=consul
WorkingDirectory=/var/lib/consul

[Unit]
Description=consul
Wants=network.target
After=network.target

[Install]
WantedBy=multi-user.target

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

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }

    Context 'can be contacted' {
        $response = Invoke-WebRequest -Uri http://localhost:8080/builds -UseBasicParsing
        $agentInformation = ConvertFrom-Json $response.Content
        It 'responds to HTTP calls' {
            $response.StatusCode | Should Be 200
            $agentInformation | Should Not Be $null
        }
    }
}
