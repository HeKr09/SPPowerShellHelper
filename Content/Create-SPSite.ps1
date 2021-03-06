﻿<#
.SYNOPSIS  
    Creates a site collection within a specific content database.
.DESCRIPTION  
    Creates a site collection within a specific content database, with a specific template, language id, url and name.
    Creates the default associated groups.
.NOTES
    File Name  : Create-SPSite.ps1
    Author     : Henrik Krumbholz
.EXAMPLE  
    Create-SPSite.ps1 -Url "http://sp.dev.local/newSite" -Name "NewSite" -SiteCollectionTemplate "STS#1" -PrimaryLogin "dev\admin"
    Creates a new site collection with name "NewSite", url "http://sp.dev.local/newSite", template "STS#1" and the primary login "dev\admin".
.EXAMPLE
    Create-SPSite.ps1 -Url "http://sp.dev.local/newSite" -Name "NewSite" -SiteCollectionTemplate "STS#1" -PrimaryLogin "dev\admin" -ContentDB "TargetContentDB"
    Creates a new site collection with name "NewSite", url "http://sp.dev.local/newSite", template "STS#1" and the primary login "dev\admin" within the content database "TargetContentDB".
.EXAMPLE
    Create-SPSite.ps1 -Url "http://sp.dev.local/newSite" -Name "NewSite" -SiteCollectionTemplate "STS#1" -PrimaryLogin "dev\admin" -ContentDB "TargetContentDB" -Language 1031
    Creates a new site collection with name "NewSite", url "http://sp.dev.local/newSite", template "STS#1", language 1031 (german) and the primary login "dev\admin" within the content database "TargetContentDB".
.EXAMPLE
    Create-SPSite.ps1 -Url "http://sp.dev.local/newSite" -Name "NewSite" -SiteCollectionTemplate "STS#1" -PrimaryLogin "dev\admin" -ContentDB "TargetContentDB" -Language 1031 -SecondaryLogin "dev\secondAdmin"
    Creates a new site collection with name "NewSite", url "http://sp.dev.local/newSite", template "STS#1", language 1031 (german), the primary admin "dev\admin" and the secondary admin "dev\secondAdmin" within the content database "TargetContentDB".
.EXAMPLE
    Create-SPSite.ps1 -Url "http://sp.dev.local/newSite" -Name "NewSite" -SiteCollectionTemplate "STS#1" -PrimaryLogin "dev\admin" -ContentDB "TargetContentDB" -Language 1031 -SecondaryLogin "dev\secondAdmin" -Description "Site Description"
    Creates a new site collection with name "NewSite", url "http://sp.dev.local/newSite", template "STS#1", language 1031 (german), description "Site Description", the primary admin "dev\admin" and the secondary admin "dev\secondAdmin" within the content database "TargetContentDB".
.PARAMETER Url
    The url of the new site to be created. Needs to be full qualified.
.PARAMETER ContentDB
    The name of the target content database. If empty SharePoint is going to choose the content database.
.PARAMETER Name
    The name of the new site to be created.
.PARAMETER Description
    The description of the new site to be created.
.PARAMETER SiteCollectionTemplate
    The template of the new site to be created. Needs to be noted as <WebTemplate#WebTemplateId>. For example: STS#1
.PARAMETER PrimaryLogin
    The primary site collection administrator of the new site to be created. Needs to be noted as <Domain\Account>.
.PARAMETER SecondaryLogin
    The secondary site collection administrator of the new site to be created. Needs to be noted as <Domain\Account>.
.PARAMETER Language
    The language code of the new site to be created. Default is 1033 (en).
#>

##############################
#
# Parameters
#
##############################

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Url,

    [Parameter(Mandatory = $false)]
    [string]
    $ContentDB,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Name,

    [Parameter(Mandatory = $false)]
    [string]
    $Description = "",

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $SiteCollectionTemplate,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $PrimaryLogin,

    [Parameter(Mandatory = $false)]
    [string]
    $SecondaryLogin = $PrimaryLogin,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Language = 1033
)

##############################
#
# Snapins
#
##############################

Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

##############################
#
# Main
#
##############################

Write-Verbose "Creating root site collection"

if ([string]::IsNullOrEmpty($ContentDB)) {
    New-SPSite -Url $Url -Name $Name –Description $Description -Template $SiteCollectionTemplate -OwnerAlias $PrimaryLogin -Language $Language -SecondaryOwnerAlias $SecondaryLogin | Out-Null
}
else {
    New-SPSite -Url $Url –ContentDatabase $ContentDB -Name $Name –Description $Description -Template $SiteCollectionTemplate -OwnerAlias $PrimaryLogin -Language $Language -SecondaryOwnerAlias $SecondaryLogin | Out-Null
}

$web = Get-SPWeb $Url
if ($null -ne $web -and $null -eq $web.AssociatedVisitorGroup) {
    Write-Verbose 'The Visitor Group does not exist. It will be created...'
    [Microsoft.SharePoint.SPSecurity]::RunWithElevatedPrivileges(
        {
            $tmpWeb = Get-SPWeb $Url
            $tmpWeb.CreateDefaultAssociatedGroups($PrimaryLogin, $SecondaryLogin, [System.String].Empty)
            $tmpWeb.Dispose()
        }
    )
    Write-Verbose 'The default Groups have been created.'
}
else {
    Write-Verbose 'The Visitor Group already exists.'
}
$web.Dispose()

Write-Verbose "Root site collection created"