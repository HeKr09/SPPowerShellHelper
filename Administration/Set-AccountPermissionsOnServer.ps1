param(
    [Parameter(Mandatory=$true, ParameterSetName="SharePoint")]
    [ValidateNotNullOrEmpty()]
    [string]
    $SpInstallAccountName,
    
    [Parameter(Mandatory=$true, ParameterSetName="SharePoint")]
    [ValidateNotNullOrEmpty()]
    [string]
    $SpFarmAccountName,
    
    [Parameter(Mandatory=$true, ParameterSetName="SharePoint")]
    [ValidateNotNullOrEmpty()]
    [string]
    $SpUserProfileAccountName,
    
    [Parameter(Mandatory=$true, ParameterSetName="SQL")]
    [ValidateNotNullOrEmpty()]
    [string]
    $SqlInstallAccountName
)

Import-Module activedirectory

if($PSCmdlet.ParameterSetName -eq "SharePoint")
{
    Write-Verbose "Adding SharePoint install account to local administrators"
    Add-ADGroupMember -Identity "Administrators" -Members $SpInstallAccountName

    Write-Verbose "Adding SharePoint farm account to local administrators"
    Add-ADGroupMember -Identity "Administrators" -Members $SpFarmAccountName

    Write-Verbose "Adding SharePoint user profile account to local administrators"
    Add-ADGroupMember -Identity "Administrators" -Members $SpUserProfileAccountName
    
    Write-Verbose "Adding SharePoint install account to remote desktop users"
    Add-ADGroupMember -Identity "Remote Desktop Users" -Members $SpInstallAccountName

    Write-Verbose "Adding SharePoint install account to remote desktop users"
    Add-ADGroupMember -Identity "Remote Desktop Users" -Members $SpFarmAccountName
}

if($PSCmdlet.ParameterSetName -eq "SQL")
{
    Write-Verbose "Adding SQL install account to local administrators"
    Add-ADGroupMember -Identity "Administrators" -Members $SqlInstallAccountName
    
    Write-Verbose "Adding SQL install account to remote desktop users"
    Add-ADGroupMember -Identity "Remote Desktop Users" -Members $SqlInstallAccountName
}