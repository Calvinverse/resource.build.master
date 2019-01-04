[CmdletBinding()]
param(
    [string] $jenkinsVersion = '2.150'
)

$ErrorActionPreference = 'Stop'
$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters['Verbose'] -eq $true;
        ErrorAction = $ErrorActionPreference
    }

$expectedPluginsPath = Join-Path $PSScriptRoot 'plugins.xml'
$expectedPlugins = [xml](Get-Content -Path $expectedPluginsPath | Out-String)

$jenkinsPluginUrl = "https://updates.jenkins.io/$($jenkinsVersion)/update-center.actual.json"
Write-Verbose "Getting plugin information from $jenkinsPluginUrl ..."
$response = Invoke-WebRequest `
    -Uri $jenkinsPluginUrl `
    -UseBasicParsing `
    @commonParameterSwitches
$json = ConvertFrom-Json $response.Content
$plugins = $json.plugins

$rubyIncludeFile = Join-Path (Join-Path (Join-Path (Join-Path $PSScriptRoot 'cookbooks') 'resource_build_master') 'attributes' ) 'jenkins_plugin_versions.rb'
Write-Verbose "Found ruby fille at: $rubyIncludeFile"

$fileContent = '# frozen_string_literal: true' + [System.Environment]::NewLine
$fileContent += '' + [System.Environment]::NewLine
$fileContent += "default['jenkins']['plugins'] = {" + [System.Environment]::NewLine

Write-Verbose "Getting versions for plugins ..."
$childItems = $expectedPlugins.DocumentElement.ChildNodes
for ($i = 0; $i -lt $childItems.Count; $i++)
{
    $element = $childItems[$i]
    $pluginName = $element.Attributes["id"].Value
    $pluginVersion = $element.Attributes["version"].Value

    if ($pluginVersion -eq $null)
    {
        Write-Verbose "Finding version for $pluginName ..."
        $plugin = $plugins."$($pluginName)"
        if (($plugin -eq $null) -or ($plugin.name -eq '') -or ($plugin.name -eq $null))
        {
            continue
        }

        $pluginVersion = $plugin.version
    }

    Write-Verbose "Version for $pluginName is $pluginVersion"

    $text = "  '$($pluginName)' => '$($pluginVersion)'"
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

Write-Output "Plugin list processed. Include file is at: $($rubyIncludeFile)"
