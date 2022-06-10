Remove-Module *
Import-Module SendMail,UACTranslator,CreateHtml
 
# Variable ADAPT AS REQUIRED
$domain = 'NA'
$SendTo = aliou.traore-ext@socgen.com
 
# Variable DO NOT TOUCH
$temporaryResultsFilePath = ".\" + $domain.ToLower() + ".all.groups.xml"
$ResultFilePath = ".\" + $domain.ToLower() + ".empty.groups.csv"
$myHTMLfile = ".\" + $domain.ToLower() + ".empty.groups.html"
$Title = "search for empty groups"
 
# clear the window
clear
write-host "`n`n`n`n`n "
write-host "`nStarting $Title"
 
# Creates empty hashs to export
$AllGroups = @()
$Empty_Groups = @()
$Empty_ones = @()
$Non_Empty = @()
 
if (-not (Test-Path -Path $temporaryResultsFilePath) ) {
 
    # gather all groups
    $AllGroups = Get-ADGroup -Filter * -Properties Members,
                                                   MemberOf,
                                                   Name,
                                                   isCriticalSystemObject,
                                                   Description,
                                                   ManagedBy,
                                                   GroupCategory,
                                                   GroupScope,
                                                   groupType,
                                                   WhenCreated,
                                                   WhenChanged,
                                                   DistinguishedName,
                                                   SIDHistory
 
    #export the hash to an XML file as we do not need this to be updated each time we run the script
    $AllGroups | Export-Clixml -Path $temporaryResultsFilePath -Encoding UTF8 -Depth 20 -Force
 
}
else
{
    $AllGroups = Import-Clixml -Path $temporaryResultsFilePath -Encoding UTF8
}
 
foreach ( $Group in $AllGroups ) {
 
 
    if (($Group.Members | measure-object).count -eq 0)
    {
        $Empty_Groups += $Group
    }
    else
    {
        $Non_Empty += $Group
    }
 
}
 
# gather all selected
$Empty_ones = $Empty_Groups |
                Select Name,isCriticalSystemObject,Description,ManagedBy,
                       @{Label = 'MemberOf'; Expression = {($_.MemberOf | ForEach-Object {($_) -join ","})}},
                       @{Label = 'Members'; Expression = {($_.Members | ForEach-Object {($_) -join ","})}},
                       GroupCategory,GroupScope,groupType,
                       WhenCreated,WhenChanged,
                       DistinguishedName,
                       @{Label = 'SidHistory'; Expression = {($_.SIDHistory | ForEach-Object {($_) -join ","})}}
 
# Count the object
$HowMany = ($Empty_ones | measure-Object).Count
 
# Display how many found
Write-host ("`nThere is $HowMany empty groups in $domain .")
 
Write-Debug ($Empty_ones | FL | out-string)
Write-Host "`nData preparation is done and will be saved."
 
#export the hash to a csv file
$Empty_ones | export-csv -Path $ResultFilePath -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Force
 
#export the hash to an html file
$Html = Set-HtmlTable -TblObjects $Empty_ones -Divtitle "Results of $Title : $HowMany " 
 
Set-HtmlPage -Tabtitle ("Empty Groups") -Fragments $Html |
    out-file -FilePath $myHTMLfile
 
# display where the files are
Write-Host "`nResults exported to csv : $ResultFilePath"
Write-Host "`nHTML is here : $myHTMLfile"
 
# Show results within HTML file
invoke-expression $myHTMLfile
 
#Send a mail containing CSV files attached
Send-Mail -MailSubject "Results of $Title : $HowMany " -HTMLBody (Get-content $myHTMLfile | Out-String) -Attachment ((get-item $ResultFilePath).FullName) -To $SendTo
 
#The End
write-host "`nThe End."