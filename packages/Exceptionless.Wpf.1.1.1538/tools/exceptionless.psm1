﻿function find_config($project) {
	$configPath = $null

	if ($project -eq $null -or $project.ProjectItems -eq $null) {
		return $configPath
	}

	try {
		$config = $project.ProjectItems.Item("Web.config")
	} catch { }
	
	if ($config -eq $null) {
		try {
			$config = $project.ProjectItems.Item("App.config")
		} catch { }
	}

	if ($config -ne $null) {
		try {
			$configPath = $config.Properties.Item("LocalPath").Value
		} catch { }
	}

	return $configPath
}

function update_config($configPath, $platform) {
	[xml] $configXml = gc $configPath
	$shouldSave = $false

	if ($configXml -ne $null) {
		$configSection = $configXml.SelectSingleNode("configuration/configSections/section[@name='exceptionless']")
		if ($configSection -eq $null) {
			$parentNode = $configXml.SelectSingleNode("configuration/configSections")
			if ($parentNode -eq $null) {
				if($configXml.SelectSingleNode("configuration").ChildNodes.Count -eq 0) {
					$parentNode = $configXml.SelectSingleNode("configuration").AppendChild($configXml.CreateElement('configSections'))
				} else {
					$parentNode = $configXml.SelectSingleNode("configuration").InsertBefore($configXml.CreateElement('configSections'), $configXml.SelectSingleNode("configuration").ChildNodes[0])
				}
			}
			$configSection = $configXml.CreateElement('section')
			$configSection.SetAttribute('name', 'exceptionless')
			$configSection.SetAttribute('type', 'Exceptionless.Configuration.ExceptionlessSection, Exceptionless')
			
			$parentNode.AppendChild($configSection)
			$shouldSave = $true
		}
		
		if ($configXml.SelectSingleNode("configuration/exceptionless") -eq $null) {
			$exceptionlessNode = $configXml.CreateElement('exceptionless')
			$exceptionlessNode.SetAttribute('apiKey', 'API_KEY_HERE')
			
			$target = $configXml.configuration['system.web']
			$configXml.SelectSingleNode("configuration").InsertBefore($exceptionlessNode, $target)
			$shouldSave = $true
		}
		
		if ($platform -ne $null -and $platform -ne 'WebApi') {
			$webServerModule = $configXml.SelectSingleNode("configuration/system.webServer/modules/add[@name='ExceptionlessModule']")
			if ($webServerModule -eq $null) {
				$parentNode = $configXml.SelectSingleNode("configuration/system.webServer")
				if ($parentNode -eq $null) {
					$parentNode = $configXml.SelectSingleNode("configuration").AppendChild($configXml.CreateElement('system.webServer'))
				}
				$parentNode = $configXml.SelectSingleNode("configuration/system.webServer/modules")
				if ($parentNode -eq $null) {
					$parentNode = $configXml.configuration['system.webServer'].AppendChild($configXml.CreateElement('modules'))
				}
				$webServerModule = $configXml.CreateElement('add')
				$webServerModule.SetAttribute('name', 'ExceptionlessModule')
				$webServerModule.SetAttribute('type', 'Exceptionless.' + $platform + '.ExceptionlessModule, Exceptionless.' + $platform)
				
				$parentNode.AppendChild($webServerModule)
				$shouldSave = $true
			}
		}
		
		if ($shouldSave -eq $true) {
			$configXml.Save($configPath)
		}
	}
}

function remove_config($configPath) {
	[xml] $configXml = gc $configPath
	$shouldSave = $false

	if ($configXml -ne $null) {
		$configSection = $configXml.SelectSingleNode("configuration/configSections/section[@name='exceptionless']")
		if ($configSection -ne $null) {
			[Void]$configSection.ParentNode.RemoveChild($configSection)
			$shouldSave = $true
		}
		
		$configSection = $configXml.SelectSingleNode("configuration/exceptionless")
		if ($configSection -ne $null) {
			if ($configSection.HasAttribute("apiKey") -and ($configSection.GetAttribute("apiKey") -ne 'API_KEY_HERE') -and ($configSection.GetAttribute("apiKey").length -gt 10)) {
				"Exceptionless API Key has been configured and will not be removed."
			} else {
				[Void]$configSection.ParentNode.RemoveChild($configSection)
				$shouldSave = $true
			}
		}
		
		$webModule = $configXml.SelectSingleNode("configuration/system.web/httpModules/add[@name='ExceptionlessModule']")
		if ($webModule -ne $null) {
			[Void]$webModule.ParentNode.RemoveChild($webModule)
			$shouldSave = $true
		}
		
		$webServerModule = $configXml.SelectSingleNode("configuration/system.webServer/modules/add[@name='ExceptionlessModule']")
		if ($webServerModule -ne $null) {
			[Void]$webServerModule.ParentNode.RemoveChild($webServerModule)
			$shouldSave = $true
		}
		
		
		if ($shouldSave -eq $true) {
			$configXml.Save($configPath)
		}
	}
}

function add_attribute($sourceFile) {
	if (!(test-path $sourceFile)) {
	    return
	}
	
	$input = get-content $sourceFile
	$isUpdated = $input | Select-String "Exceptionless" -quiet
	
	if ($isUpdated) {
	   return
	}
	
	# seems to insure a linefeed
	"" | Out-file $sourceFile -append
	if ([string]$sourceFile.EndsWith('.vb')) {
		'<assembly: Exceptionless.Configuration.Exceptionless("API_KEY_HERE")>' | Out-File $sourceFile -append
	} else {
		'[assembly: Exceptionless.Configuration.Exceptionless("API_KEY_HERE")]' | Out-File $sourceFile -append
	}
}