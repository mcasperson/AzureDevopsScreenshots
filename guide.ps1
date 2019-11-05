param([String] $Password, [String] $SlackHook)

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential 'hostname\testadmin', $securePassword
Invoke-Command -Authentication CredSSP -ScriptBlock {C:\OctopusGuides\install.ps1 -Scripts azuredevops.pp,utilities.pp,azurewait.pp} -ComputerName hostname -Credential $credential
Invoke-Command -Authentication CredSSP -ScriptBlock {
  param($SlackHook)
  Start-Process 'C:\Program Files\OpenJDK\jdk-13\bin\java' -ArgumentList @('--enable-preview', "-DslackHookUrl=$SlackHook", '-Dwebdriver.gecko.driver=C:\tools\geckodriver.exe', '-DslackStepHandlerEnabled=true', '-DretryCount=3', '-jar', 'c:\tools\webdrivertraining-1.0-SNAPSHOT.jar', '--tags', '"(@login or @install-extensions)"', 'C:\OctopusGuides\features\azuredevops\azuredevops-aspnet-project.feature') -Wait
} -ComputerName hostname -Credential $credential -ArgumentList $SlackHook; 
