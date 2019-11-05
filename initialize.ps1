reg add 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' /v DisableRealtimeMonitoring /t REG_DWORD /d 1
Enable-WSManCredSSP -Role Server -Force
Enable-WSManCredSSP -Role Client -DelegateComputer * -Force
Set-Item -Path 'WSMan:\localhost\Service\Auth\CredSSP' -Value $true
New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentialsWhenNTLMOnly -Force
New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name 1 -Value * -PropertyType String
enable-psremoting -force
