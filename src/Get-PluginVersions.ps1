[CmdletBinding()]
param(
    [string] $jenkinsVersion = '2.121'
)

$ErrorActionPreference = 'Stop'
$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters['Verbose'] -eq $true;
        ErrorAction = $ErrorActionPreference
    }

$expectedPluginsPath = Join-Path $PSScriptRoot 'plugins.xml'
$expectedPlugins = [xml](Get-Content -Path $expectedPluginsPath | Out-String)

$response = Invoke-WebRequest `
    -Uri "https://updates.jenkins.io/$($jenkinsVersion)/update-center.actual.json" `
    -UseBasicParsing `
    @commonParameterSwitches
$json = ConvertFrom-Json $response.Content
$plugins = $json.plugins

$rubyIncludeFile = Join-Path (Join-Path (Join-Path (Join-Path $PSScriptRoot 'cookbooks') 'resource_build_controller') 'attributes' ) 'jenkins_plugin_versions.rb'

$fileContent = '# frozen_string_literal: true' + [System.Environment]::NewLine
$fileContent += '' + [System.Environment]::NewLine
$fileContent += "default['jenkins']['plugins'] = {" + [System.Environment]::NewLine

$childItems = $expectedPlugins.DocumentElement.ChildNodes
for ($i = 0; $i -lt $childItems.Count; $i++)
{
    $element = $childItems[$i]
    $plugin = $plugins."$($element.InnerText)"
    if (($plugin.name -eq '') -or ($plugin.name -eq $null))
    {
        continue
    }

    $text = "  '$($plugin.name)' => '$($plugin.version)'"
    if (($i + 1) -ne $childItems.Count)
    {
        $text += ','
    }
    $fileContent += $text + [System.Environment]::NewLine
    Out-File -FilePath $rubyIncludeFile -InputObject $text -Append -Force
}

$fileContent += '}'

$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines($rubyIncludeFile, $fileContent, $Utf8NoBomEncoding)
