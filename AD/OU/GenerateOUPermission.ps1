Remove-Module *

 

#region Script Location

 

    function Get-ScriptName {

        return $MyInvocation.ScriptName | Split-Path -Leaf

    }

 

    # Gets Script Name

    $scriptName = Get-ScriptName

    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptName)

   

    # Determine script location for PowerShell

    $ScriptPath = split-path -parent $MyInvocation.MyCommand.Definition

 

    # Determine current location

    Push-Location

    $SAVWorkDir = Get-Location

 

    # Force WorkDir to be the same as Script location

    if ($SAVWorkDir -ne $ScriptPath) {

        Set-Location $ScriptPath

    }

 

#endregion

 

#region Logs Location 

    

    # Looks where the logs folder should be

    $LogsPath =  "D:\_logs\$scriptName"

 

    # Check for existing Log location or creates it

    if (-not(Test-Path "D:\_logs")) {

        New-Item -Path "D:\" -Name "_logs" -ItemType "directory" | out-Null

    } elseif (-not(Test-Path $LogsPath)) {

        New-Item -Path "D:\_logs\" -Name $scriptName -ItemType "directory" | out-Null

    }

 

#endregion

 

#region Result Location 

    

    # Looks where the Result folder should be

    $ResultPath =  "D:\_results\$scriptName"

 

    # Check for existing Result location or creates it

    if (-not(Test-Path "D:\_results" )) {

        New-Item -Path "D:\" -Name "_results" -ItemType "directory" | out-Null

    } elseif (-not(Test-Path $ResultPath)) {

        New-Item -Path "D:\_results\" -Name $scriptName -ItemType "directory" | out-Null

    }

 

#endregion

 

#region User Variables

 

    $BaseFileName =  $FileTimeStp_Str + "_" + $scriptName

    $Title = "Generate Report on all OUs Permissions from $Domain"

    $Pagetitle = $Title

   

 

#endregion

 

#region Script variables

 

    # Collect Users Storage variable

    #$colUsers = @()

 

    # File names and paths

    $myHTMLfile     = "$ResultPath\" + $BaseFileName + ".html"

    $logFile        = "$LogsPath\" + $BaseFileName + ".log"

    $ZipFile        = "$ResultPath\" + $BaseFileName + ".zip"

 

    $UnresolvedSIDfile = "$ResultPath\" + "OU_Permissions_UnresolvedSID_" + $Today + ".csv"

    if(Test-Path $UnresolvedSIDfile)

    {

        Remove-Item $UnresolvedSIDfile -Force -Confirm $false

    }   

 

    $AllPermissionsFile = "$ResultPath\" + "OU_Permissions_All_" + $Today + ".csv"

    if(Test-Path $AllPermissionsFile)

    {

        Remove-Item $AllPermissionsFile -Force -Confirm $false

    }

 

    $UserAccountsStatesFile = "$ResultPath\" + "UserAccountsStates_" + $Today + ".csv"

    if(Test-Path $UserAccountsStatesFile)

    {

        Remove-Item $UserAccountsStatesFile -Force -Confirm $false

    }

 

#endregion

 

# clear the window

Clear-Host

Start-Transcript -Path $logFile

 

#region Time / Date Info

 

    $DateRef         = [datetime]::Now

    $FileTimeStp_Str = $DateRef.ToString("yyyyMMdd.hhmmss")

    $Today           = $DateRef.ToString("yyyyMMdd-HHmm")

 

#endregion

 

#region Load AD Module

    try{

        Import-Module ActiveDirectory -ErrorAction Stop

    }

    catch{

        Write-Warning "Unable to load Active Directory PowerShell Module"

    }

#endregion

 

#region Load SendMail and CreateHtml Module

 

try{

        Import-Module SendMail -ErrorAction Stop

    }

    catch{

        Write-Warning "Unable to load SendMail Module"

    }

try{

        Import-Module CreateHtml -ErrorAction Stop

    }

    catch{

        Write-Warning "Unable to load CreateHtml Module"

    }

 

#endregion#

 

#region Active Directory Variables

    $ADDomain  = Get-ADDomain

    $Domain    = $ADDomain.NetBiosName

    $DN        = $ADDomain.DistinguishedName

    $PDC       = $ADDomain.PDCEmulator

#endregion

 

#region System Settings

    

    # Parameters for Import and Export CSV (another way of doing)

    $textDelimiter = ';'

 

    # Parameters for Import and Export CSV

    $Param4CSV = @{

        Delimiter         = $textDelimiter

        Encoding          = "UTF8"

        NoTypeInformation = $true

        Path              = ""

    }

 

    $Welknowns = @(

      "S-1-1-0",

      "S-1-3-0",

      "S-1-5-2",

      "S-1-5-11",

      "S-1-5- -502",

      "S-1-5- -515",

      "S-1-5-32-544",

      "S-1-5-32-548",

      "S-1-5-32-554",

      "S-1-5-32-545",

      "S-1-5-32-546",

      "S-1-5-32-557",

      "BUILTIN\Administrators",

      "BUILTIN\Print Operators",

      "$Domain\Enterprise Admins",

      "$Domain\Organization Management",

      "$Domain\Exchange Recipient Administrators",

      "$Domain\Exchange Trusted Subsystem",

      "$Domain\Exchange Windows Permissions",

      "$Domain\Exchange Organization Administrators",

      "$Domain\Exchange Public Folder Administrators",

      "$Domain\Exchange Servers",

      "$Domain\Administrator",

      "$Domain\RTCHSUniversalServices",

      "$Domain\Delegated Setup",

      "$Domain\Enterprise Read-only Domain Controllers",

      "$Domain\Public Folder Management",

      "$Domain\RTCUniversalServerReadOnlyGroup",

      "$Domain\Exchange Enterprise Servers",

      "$Domain\Exchange Admin Group",

      "$Domain\Domain Controllers",

      "$Domain\Domain Admins",

      "$Domain\Exchange Domain Servers",

      "$Domain\Cloneable Domain Controllers",

      "$Domain\RTCHSDomainServices",

      "NT AUTHORITY\NETWORK SERVICE",

      "NT AUTHORITY\ENTERPRISE DOMAIN CONTROLLERS",

      "NT AUTHORITY\Authenticated Users",

      "NT AUTHORITY\SYSTEM",

      "NT AUTHORITY\SELF",

      "Everyone"

    )

 

#endregion System Settings

 

# This array will hold the report output.

$report = @()          

 

#region Gets SchemaGUIDs

 

Write-Host "### NEED TO RECONCILE THE CONFLICTS ###"

 

$ErrorActionPreference = 'SilentlyContinue'

 

$schemaIDGUID = @{}

 

Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -LDAPFilter '(schemaIDGUID=*)' `

             -Properties name, schemaIDGUID |

             ForEach-Object { $schemaIDGUID.add([System.GUID]$_.schemaIDGUID,$_.name) }

 

Get-ADObject -SearchBase "CN=Extended-Rights,$((Get-ADRootDSE).configurationNamingContext)" `

             -LDAPFilter '(objectClass=controlAccessRight)' `

             -Properties name, rightsGUID |

             ForEach-Object { $schemaIDGUID.add([System.GUID]$_.rightsGUID,$_.name) }

 

$ErrorActionPreference = 'Continue'

 

#endregion

 

# Get a list of all OUs.  Add in the root containers for good measure (users, computers, etc.).

Write-host "`n`n`n`n`n`nGetting DistinguishedName of all Organizational Units & Containers..." -backgroundColor yellow -ForegroundColor Black

 

# Getting all AD OUs leaf into one Array

$OUs = @()

$OUs += $OUsRoot  = $DN

$OUs += Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty DistinguishedName

$OUs += Get-ADObject -SearchBase $OUsRoot -SearchScope OneLevel -LDAPFilter '(objectClass=container)' | Select-Object -ExpandProperty DistinguishedName

 

# HowMany OUs do we found

$OUcount = $OUs.count

 

#region Prepare output files

 

    # Loop through each of the OUs and retrieve their permissions.

    # Add report columns to contain the OU path and string names of the ObjectTypes.

 

    Write-host "`n`nAnalyzing Permissions for each of the $OUcount Organizational Units & Containers..." -backgroundColor yellow -ForegroundColor Black

 

    $cptOU = 1

 

 

    ForEach ($OU in $OUs) {

 

        write-progress -activity "`t`t[$cptOU/$OUcount] ...$OU..."

 

        $cptOU++

        #set-location -PATH AD:

        $report += Get-Acl -Path "AD:\$OU" |

         Select-Object -ExpandProperty Access |

         Select-Object @{name='organizationalUnit';expression={$OU}}, `

                       @{name='objectTypeName';expression={if ($_.objectType.ToString() -eq '00000000-0000-0000-0000-000000000000') {'All'} Else {$schemaIDGUID.Item($_.objectType)}}}, `

                       @{name='inheritedObjectTypeName';expression={$schemaIDGUID.Item($_.inheritedObjectType)}}, `

                       * |

        Select-Object IdentityReference,

                      organizationalUnit,

                      objectTypeName,

                      inheritedObjectTypeName,

                      ActiveDirectoryRights,

                      AccessControlType,

                      IsInherited,

                      InheritanceType,

                      ObjectFlags,

                      InheritanceFlags,

                      PropagationFlags  |

        Where-Object IdentityReference -notin $Welknowns

 

        $currentPurcent = ($cptOU)*100 / $OUcount

    }

 

    $TotalArray = $report.count

 

    write-host "Getting state of each forest user accounts..."  -backgroundColor yellow -ForegroundColor Black

    $UserAccountsStates = (Get-ADUser -Filter * -Server "$($PDC):3268" | Select-Object samaccountname,Enabled)

   

    # Unresolved SIDs

    write-host "`n`nExporting Unresolved SIDs for each of the $OUcount Organizational Units & Containers"  -backgroundColor yellow -ForegroundColor Black

   

    $reportUnresolvedSIDs = @()

    $currentPurcent = 0

    $cpt = 0

 

    $report |

       Sort-Object organizationalUnit,IdentityReference,objectTypeName |

       Select-Object organizationalUnit,

                     IdentityReference,

                     objectTypeName,

                     inheritedObjectTypeName,

                     ActiveDirectoryRights,

                     AccessControlType,

                     IsInherited,

                     InheritanceType,

                     ObjectFlags,

                     InheritanceFlags,

                     PropagationFlags |

       Where-Object {($_.IdentityReference -like "S-1-5-21*") -and ($_.IsInherited -eq $false)} |

       ForEach-Object {

            $ActivityUpd  = "Checking Unresolved Permissions for each of the $OUcount Organizational Units & Containers = ["

            $ActivityUpd += "$($reportUnresolvedSIDs.count)/" + $TotalArray + "] "

            $ActivityUpd += "$($_.organizationalUnit) - "

            $ActivityUpd += "$($_.IdentityReference) - "

            $ActivityUpd += "$($_.objectTypeName) - "

            $ActivityUpd += "$($_.IsEnabled)"

 

            write-progress -activity $ActivityUpd `

                           -status "$([System.Math]::Round($currentPurcent,2))% Complete:" `

                           -percentcomplete $currentPurcent

 

            $reportUnresolvedSIDs += $_

 

            $currentPurcent = $cpt*100 / $TotalArray

            $cpt++

         }

 

 

#endregion

 

Write-Debug ($UserAccountsStates | Format-List | out-string)

Write-Debug ($report | Format-List | out-string)

Write-Debug ($reportUnresolvedSIDs | Format-List | out-string)

Write-Host "`nData preparation is done and will be saved."

 

#export the hashes to a csv file

$Param4CSV.path = $UserAccountsStatesFile

$UserAccountsStates | Export-Csv @Param4CSV

write-host "`n`nExporting All Permissions for all of the $OUcount Organizational Units & Containers..."  -backgroundColor yellow -ForegroundColor Black

$Param4CSV.path = $AllPermissionsFile

$report | Export-Csv @Param4CSV

$Param4CSV.path = $UnresolvedSIDfile

$reportUnresolvedSIDs| Export-Csv @Param4CSV

 

#export the hash to an html file

$Html_UserAccountsStates = Set-HtmlTable -TblObjects $UserAccountsStates -Divtitle "User Account States"

$Html_report = Set-HtmlTable -TblObjects $report  -Divtitle "Report"

$Html_reportUnresolvedSIDs = Set-HtmlTable -TblObjects $reportUnresolvedSIDs  -Divtitle "Unresolved SIDs"

$Html = $Html_UserAccountsStates + $Html_report + $Html_reportUnresolvedSIDs

$FinalHtml = Set-HtmlPage -Tabtitle ("OUs Permissions in $Domain") -Fragments $Html

 

$FinalHtml | out-file -FilePath $myHTMLfile

 

# display where the files are

Write-Host "`nResults exported to csv : $UserAccountsStatesFile"

Write-Host "`nResults exported to csv : $AllPermissionsFile"

Write-Host "`nResults exported to csv : $UnresolvedSIDfile"

Write-Host "`nHTML is here : $myHTMLfile"

 

# Compress result files in one zip file

Compress-Archive -Path $UserAccountsStatesFile -DestinationPath $ZipFile -Force

Compress-Archive -Path $AllPermissionsFile -Update -DestinationPath $ZipFile

Compress-Archive -Path $UnresolvedSIDfile -Update -DestinationPath $ZipFile

 

#Send a mail containing CSV files attached

$MailParameters = @{

    MailSubject = $Pagetitle

    HTMLBody    = $(Get-content $myHTMLfile | Out-String)

    Attachment  = ((get-item $ZipFile).FullName)

    To          = (aliou.traore-ext@socgen.com,philippe.grivel-ext@socgen.com)

}

 

Send-Mail @MailParameters

 

$stop = [datetime]::Now

$runTime = New-TimeSpan $DateRef $stop

Write-Output "Script Runtime: $runtime"

 

# End

$startupVariables=""

new-variable -force -name startupVariables -value (Get-Variable | ForEach-Object { $_.Name })

 

Get-Variable |

    Where-Object { $startupVariables -notcontains $_.Name } |

    ForEach-Object {

        Remove-Variable -Name "$($_.Name)" -Force -Scope "global" -ErrorAction SilentlyContinue

      }

Write-Output "The End."

Stop-Transcript

Pop-Location

 

# Show results within HTML file

invoke-expression $myHTMLfile