Function Copy-ToVM {
<#
.SYNOPSIS
Copies files from a Hyper-V host to a VM using PowerShell Direct. This only works if the VM is Server 2016 and above.
.DESCRIPTION 
This script copies the files from the specified Source folder onto the host that the VM resides on. The files go into the c:\temp directory in a folder called "VMFiles".
Once the files are there, it creates a pssession to the VM that was entered in the VMName parameter. The VMFiles folder is then copied into C:\Temp folder on the VM.
.PARAMETER VMMServer
This is the name of the VMM server that runs the Hyper-v Infrastructure.
.PARAMETER VMName
Name of the VM that the files will be copied to. This must be the VM Name and not the Computer Name (if they are different)
.PARAMETER SourcePath
Location of files that need to be copied to the VM. This can be a local path or a UNC path
.PARAMETER VMCredentialUserName
This is the credentials that has Admin access to the VM. The format needs to be Domain\User. Once the script starts , a pop up box will appear to ask for the paswword. 
.EXAMPLE
Copy-ToVM -VMMServer VMMserver01 -VMname VM01  -SourcePath 'C:\Temp\vmfiles\file1.log' -VMCredentialUserName Domain\User
#>

     [CMDletBinding()]
     Param(
          [Parameter(Mandatory=$True)]  
          [String]$VMMServer,
          [Parameter(Mandatory=$True)]  
          [String]$VMname,
          [Parameter(Mandatory=$True)]
          [String]$SourcePath,
          [Parameter(Mandatory=$True)]
          [pscredential]$VMCredentialUserName
                    
          )


Begin{
$ErrorActionPreference = 'Stop'

# Assign initial Variables (Host that the VM resides on)

    Try {

        $Hostname = Get-SCVirtualMachine -VMMServer $VMMServer -name $VMname | select -ExpandProperty hostname

        }  #Try

  Catch {
     
           Write-Warning  "Server query failed, $_.Exception.Message "
           Break

        }  #Catch
        

# Check that VM is Server 2016 (Powershell Direct Compatible) and has a valid name
    
        $IsServer2016 = Get-SCVirtualMachine -VMMServer $VMMServer -Name $VMname | select OperatingSystem 

                If   ($IsServer2016.OperatingSystem.name -like '*2016*')

                 {
                     Write-Host -ForegroundColor Yellow "`n $VMname is a 2016 Server .... script will continue " 
                 }

                ElseIf (!$IsServer2016)

                 {
                    Write-Host -ForegroundColor Red "`n $VMname is not a valid servername, script will Exit."
                    Break    
                 }

                Else 

                 {
                     Write-Host -ForegroundColor Red "`n $VMname is not Server 2016 it's not gonna work, script will Exit."
                     Break
                 }
   

# Check for sufficient disk space on host

     Try { 
             $SrcFileSize = [Math]::Round((Get-ChildItem $SourcePath | Measure-Object -Property length -Sum | select -ExpandProperty sum)/1GB,2)
             $HostDriveSize = [Math]::Round((Get-CimInstance -ComputerName $Hostname -Query "Select * from win32_logicaldisk WHERE DeviceID = 'C:'" | select -ExpandProperty FreeSpace)/1GB,2)

                If  (($HostDriveSize - $SrcFileSize) -gt 5)

                 {
                     Write-host -ForegroundColor Yellow "`n More than 5GB free on $Hostname C Dive after File Copy ("$HostDriveSize GB Free ") .... Script will continue"
                 }

                Else 

                 {
                     Write-Host -ForegroundColor Red "`n Less than 5GB free space after copy on C Drive on $Hostname ..... clear some space first .... Script will Exit"
                     Break
                 }

         }  #Try

   Catch {
     
             Write-Warning  "Server query failed, $_.Exception.Message "
             Break

         }  #Catch
         

# Check for sufficient space on VM

     Try {   
                $VMDiskSpace = Invoke-Command  -ComputerName $Hostname -ScriptBlock{ 
                                                  
                      $VMSession = New-PSSession -VMName $Using:VMname -Credential $Using:VMCredentialUserName

                      Invoke-Command -Session $VMSession -ScriptBlock{
                      [Math]::Round((Get-CimInstance -Query "Select * from win32_logicaldisk WHERE DeviceID = 'C:'" | select -ExpandProperty FreeSpace)/1GB,2)}

                      } #Invoke

                If  (($VMDiskSpace - $SrcFileSize) -gt 5)
                 {
                     Write-host -ForegroundColor Yellow "`n More than 5GB free on $VMname C Dive after File Copy ("$VMDiskSpace GB Free ") .... Script will continue"
                 }
                Else 
                 {
                     Write-Host -ForegroundColor Red "`n Less than 5GB free space after copy on C Drive on $VMname ..... clear some space first .... Script will Exit"
                     Break
                 }

        }  #Try

  Catch {
           Write-Warning  "Server query failed, $_.Exception.Message "
           Break

        }  #Catch

}  # Begin
    

Process{


# Add c:\Temp\VMFiles folder to Host where VM resides

    Try {
       
            New-Item -ItemType Directory -Path \\$Hostname\c$\Temp\VMfiles -Force | Out-Null
            Write-Host -ForegroundColor Green "`n VMFiles Folder created in C:\Temp on $Hostname"

        }   #Try

  Catch {
            Write-Warning  "Server query failed, $_.Exception.Message "
            Break

        }   #Catch

# Copying Files from Source Patch to Host where VM resides.

  
    Try {

           Write-Host -ForegroundColor Green "`n Copying files from $SourcePath to \\$Hostname\C$\Temp\VMFiles"
           Copy-Item -Path $SourcePath -Recurse -Destination \\$Hostname\C$\Temp\VMFiles -force  

        }   #Try

  Catch {
            Write-Warning  "Server query failed, $_.Exception.Message "
            Break
   
        }   #Catch         
    
# Remote Session to Host and VM for File Copy

     Try {

           Write-Host -ForegroundColor Green "`n Copying VMFiles Folder to $VMName into C:\Temp"

           Invoke-Command  -ComputerName $Hostname -ScriptBlock { 
                                                  
                    $VMSession = New-PSSession -VMName $using:VMname -Credential $using:VMCredentialUserName
                    Copy-Item -Path C:\Temp\VMFiles -Recurse -ToSession $VMSession -Destination C:\Temp -Force 
                               
                    } # Invoke

         }   #Try

   Catch {

            Write-Warning  "Server query failed, $_.Exception.Message "
            Break

         }   #Cacth
       
       
                 
} # Process

End {

          Write-Host -ForegroundColor White -BackgroundColor DarkGreen "`n Files have been copied to the VMFiles Folder under C:\Temp, on $VMName"

# Cleanup Tasks
    Try { 

          Remove-item \\$Hostname\c$\Temp\VMfiles -Recurse -Force -Confirm:$false
          Write-Host -ForegroundColor White -BackgroundColor Blue "`n VMFiles Folder has been deleted under C:\Temp on $Hostname .... This folder still remains on $VMname though"

        }

  Catch {

           Write-Warning  "Server query failed, $_.Exception.Message "
           Break

        }  #Catch


    }  #End


}  #Funtcion

