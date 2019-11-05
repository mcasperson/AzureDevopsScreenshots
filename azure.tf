resource "azurerm_resource_group" "test" {
  name     = "#{Octopus.Release.Id | Replace "-" | ToLower}"
  location = "West US"
    tags = {
      Owner = "@matthew.casperson"
  }
}

resource "azurerm_public_ip" "test" {
  name                    = "test-pip"
  location                = "${azurerm_resource_group.test.location}"
  resource_group_name     = "${azurerm_resource_group.test.name}"
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
}

resource "azurerm_virtual_network" "test" {
  name                = "acctvn"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
}

resource "azurerm_subnet" "test" {
  name                 = "acctsub"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_network_name = "${azurerm_virtual_network.test.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_interface" "test" {
  name                = "acctni"
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = "${azurerm_subnet.test.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.test.id}"
  }
}

resource "azurerm_storage_account" "test" {
  name                     = "#{Octopus.Release.Id | Replace "-" | ToLower}"
  resource_group_name      = "${azurerm_resource_group.test.name}"
  location                 = "${azurerm_resource_group.test.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "test" {
  name                  = "vhds"
  resource_group_name   = "${azurerm_resource_group.test.name}"
  storage_account_name  = "${azurerm_storage_account.test.name}"
  container_access_type = "private"
}

resource "azurerm_virtual_machine" "test" {
  name                  = "acctvm"
  location              = "${azurerm_resource_group.test.location}"
  resource_group_name   = "${azurerm_resource_group.test.name}"
  network_interface_ids = ["${azurerm_network_interface.test.id}"]
  vm_size               = "Standard_D2s_v3"

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name          = "osdisk"
    vhd_uri       = "${azurerm_storage_account.test.primary_blob_endpoint}${azurerm_storage_container.test.name}/osdisk.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "#{OSPassword}"
  }
  
  os_profile_windows_config {
    enable_automatic_upgrades = false
    provision_vm_agent = true
  }
}

resource "azurerm_virtual_machine_extension" "test" {
  name                 = "hostname"
  location             = "${azurerm_resource_group.test.location}"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_machine_name = "${azurerm_virtual_machine.test.name}"
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"
  
  protected_settings = <<PROTECTED_SETTINGS
    {
      "commandToExecute": "powershell.exe -Command \"REG ADD 'hklm\software\policies\microsoft\windows defender' /v DisableAntiSpyware /t REG_DWORD /d 1 /f; Set-ExecutionPolicy Bypass -Scope Process -Force; Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); choco install -y git; cd c:\\; & 'C:\\Program Files\\Git\\bin\\git' clone https://github.com/OctopusDeploy/OctopusGuides.git; cd OctopusGuides; & 'C:\\Program Files\\Git\\bin\\git' pull; $securePassword = ConvertTo-SecureString '#{OSPassword}' -AsPlainText -Force; $credential = New-Object System.Management.Automation.PSCredential 'hostname\\testadmin', $securePassword; Invoke-Command -ScriptBlock {C:\\OctopusGuides\\install.ps1 -Scripts azuredevops.pp,utilities.pp,azurewait.pp} -ComputerName hostname -Credential $credential; Invoke-Command -ScriptBlock {& 'C:\\Program Files\\OpenJDK\\jdk-13\\bin\\java' --enable-preview '-Dwebdriver.gecko.driver=C:\\tools\\geckodriver.exe' '-DslackHookUrl=#{SlackWebHook}' '-DslackStepHandlerEnabled=true' -jar c:\\tools\\webdrivertraining-1.0-SNAPSHOT.jar --tags '(@login or @install-extensions)' features\\azuredevops\\azuredevops-aspnet-project.feature} -ComputerName hostname -Credential $credential;\""
    }
  PROTECTED_SETTINGS
}
