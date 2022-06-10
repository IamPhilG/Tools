class Record
{
    # Class Properties   
    [String]$GroupName
    [String]$Name
    [String]$UserName
    [String]$Description
 
    # Class constructor
     Record([Object]$grp)
     {
         $this.GroupName = $grp.Name
         $this.Description = $grp.Description
         $this.SetAllNames('N/A')
     }
    Record([Object]$grp, [Object]$user)
    {
        $this.GroupName = $grp.Name
        $this.Description = $grp.Description
        $this.SetName($user.Name)
        $this.SetUserName($user.SamAccountName)
    }
 
    # Class methods
    [Void] SetAllNames ([string]$user)
    {
        $this.SetUserName($user)
        $this.SetName($user)
    }
    [Void] SetUserName ([string]$user)
    {
        $this.UserName = $user
    }
    [Void] SetName ([string]$user)
    {
        $this.Name = $user
    }
   
}
 
Import-Module ActiveDirectory
 
$domains = (Get-ADForest).Domains
$howManyDomains = ($domains | Measure-Object).Count
 
$pdc = (Get-AdDomain).pdcEmulator
 
$Groups = (Get-AdGroup -filter * -properties Description,members -server $pdc)
 
$Table = @()
 
Clear-Host
 
Foreach ($Group in $Groups) {
 
  $members = $group | Select-object -expandproperty members
 
  if (($members|Measure-Object).count -ge 1)
  {
      foreach ($Member in $members)
      {
 
       
            $foundIt = $false
            $domainToCheck = 0
            Do
            {       
                $oneUser = Get-ADObject -filter {distinguishedName -eq $Member} -Properties DistinguishedName,Samaccountname -server ($domains[$domainToCheck])
                if (($null -ne $oneUser) -and ($oneUser -ne ""))
                {
                    $foundIt = $true
                }
                $domainToCheck++
 
            } until ($foundIt -eq $true -or $domainToCheck -eq $howManyDomains )
 
       
            if ($FoundIt -and ($Member -notlike "*CN=ForeignSecurityPrincipals*"))
            {
                Write-Host "For $member I found $($oneUser.Name)" -ForegroundColor Green
                $Table += [Record]::new($Group, $oneUser)
            }
            elseif ($Member -like "*CN=ForeignSecurityPrincipals*")
            {
                Write-Host "For $member I found FSP" -ForegroundColor Yellow
                $instanceObj = [Record]::new($Group)
                $instanceObj.SetName($oneUser.Name)
                $instanceObj.SetUserName("FSP")
                $Table += $instanceObj
            }
            else
            {
                Write-Host "For $member Manual evaluation" -ForegroundColor Red
                $instanceObj = [Record]::new($Group)
                $instanceObj.SetAllNames("Unknown")
                $Table += $instanceObj
            }
       
      }
  }
  else
  {
    $Table += [Record]::new($Group)
  }
}
 
$Table | export-csv "D:\CETI\LOGS\NA--SecurityGroups.csv" -NoTypeInformation