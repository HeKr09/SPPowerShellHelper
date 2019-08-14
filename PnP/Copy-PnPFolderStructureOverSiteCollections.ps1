<#
.SYNOPSIS
    Copies a folder structure via PnP over two site collections.
.DESCRIPTION
    Copies a folder structure via PnP over two site collections.
    Can copy the included files.
    Can use only the major versions of the files.
.NOTES
    File Name  : Copy-PnPFolderStructure.ps1
    Author     : Henrik Krumbholz
.EXAMPLE
    Copy-PnPFolderStructure.ps1 -SourceRootFolder "SiteAssets" -TargetRootFolder "SiteAssets" -SourceSiteUrl "https://foo.sharepoint.com/sites/source" -TargetSiteUrl "https://foo.sharepoint.com/sites/target"
    Copies the folder structure from the library SiteAssets within https://foo.sharepoint.com/sites/source to the library SiteAssets within https://foo.sharepoint.com/sites/target.
.EXAMPLE
    Copy-PnPFolderStructure.ps1 -SourceRootFolder "SiteAssets" -TargetRootFolder "SiteAssets" -SourceSiteUrl "https://foo.sharepoint.com/sites/source" -TargetSiteUrl "https://foo.sharepoint.com/sites/target" -IncludeFiles
    Copies the folder structure and included files from the library SiteAssets within https://foo.sharepoint.com/sites/source to the library SiteAssets within https://foo.sharepoint.com/sites/target.
.EXAMPLE
    Copy-PnPFolderStructure.ps1 -SourceRootFolder "SiteAssets" -TargetRootFolder "SiteAssets" -SourceSiteUrl "https://foo.sharepoint.com/sites/source" -TargetSiteUrl "https://foo.sharepoint.com/sites/target" -IncludeFiles -UseLatestMajorVersion
    Copies the folder structure and included files with their latest major version from the library SiteAssets within https://foo.sharepoint.com/sites/source to the library SiteAssets within https://foo.sharepoint.com/sites/target.
.PARAMETER SourceRootFolder
    The name of the source root folder. Should be a library.
.PARAMETER TargetRootFolder
    The name of the target root folder. Should be a library.
.PARAMETER Credentials
    The credentials if no weblogin is available.
    The use of credentials is recommended. Use (Get-Credential).
.PARAMETER SourceSiteUrl
    The url of the source site.
    For example: https://foo.sharepoint.com/sites/source.
.PARAMETER TargetSiteUrl
    The url of the target site.
    For example: https://foo.sharepoint.com/sites/target.
.PARAMETER IncludeFiles
    Defines whether files shell be copied, too.
    Default is false. (No copying)
.PARAMETER UseLatestMajorVersion
    Defines whether only the latest major version is copied. If there is no major version no file is copied.
    Default is false. (Copies the latest version (major or minor))
#>

##############################
#
# Parameters
#
##############################

param(
    [Parameter(Mandatory=$false)]
    [pscredential]
    $Credentials,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $SourceRootFolder,
    
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $TargetRootFolder,
    
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $SourceSiteUrl,
    
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $TargetSiteUrl,
    
    [Parameter(Mandatory=$false)]
    [switch]
    $IncludeFiles,
    
    [Parameter(Mandatory=$false)]
    [switch]
    $UseLatestMajorVersion
)


##############################
#
# Functions
#
##############################

function CheckCorrectConnection{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $urlToConnect
    )

    $returningConnection = $null

    if($null -eq $Credentials)
    {
        Write-Verbose "Trying to connect to $urlToConnect via WebLogin"
        $returningConnection = Connect-PnPOnline -Url $urlToConnect -UseWebLogin -ReturnConnection
    }
    else
    {
        Write-Verbose "Trying to connect to $urlToConnect via Credentials"
        $returningConnection = Connect-PnPOnline -Url $urlToConnect -Credentials $Credentials -ReturnConnection
    }
    
    $site = Get-PnPSite
    if($site.Url -ne $urlToConnect)
    {
        Write-Error "Could not connect to correct site."
        Disconnect
        return $null
    }

    return $returningConnection
}

function CopyAndMoveFile{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourceFolder,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TargetFolder,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Activity,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ConnectionSource,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ConnectionTarget,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NewRelativeSiteUrl,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ItemName,

        [Parameter(Mandatory=$false)]
        [switch]
        $UseLatestMajorVersion
    )
    
    Write-Verbose "Getting items in $SourceFolder"
    if(-not [string]::IsNullOrEmpty($ItemName))
    {
        $sourceFile = Get-PnPFolderItem -ItemType File -FolderSiteRelativeUrl $SourceFolder -Connection $ConnectionSource -ItemName $ItemName
    }
    else
    {
        $sourceFile = Get-PnPFolderItem -ItemType File -FolderSiteRelativeUrl $SourceFolder -Connection $ConnectionSource
    }
    if($null -eq $sourceFile -or $sourceFile.Count -lt 1)
    {
        Write-Error "No files found in $SourceFolder"
        return
    }
    else
    {
        $filesFound = $sourceFile.Count
    }
    
    $i = 0
    Write-Progress -Activity $Activity -status "Copying files" -percentComplete ($i / $filesFound * 100)
    
    $sourceContext = $ConnectionSource.Context
    $targetContext = $ConnectionTarget.Context
    $target = Get-PnPFolder -Url $TargetFolder -Connection $ConnectionTarget
    $targetContext.Load($target.Files)
    $targetContext.ExecuteQuery()

    $sourceFile | ForEach-Object {
        $sourceContext.Load($_)
        $sourceContext.ExecuteQuery()
        
        Write-Progress -Activity $Activity -status "Copying file $($_.Name)" -percentComplete (++$i / $filesFound * 100)

        # Getting latest published version
        if($UseLatestMajorVersion)
        {
            if ($_.MajorVersion -lt 1)
            {
                Write-Verbose "No published version found for file $($_.Name)"
            }
            else
            {
                if ($_.MinorVersion -eq 0)
                {
                    Write-Verbose "Major version $($_.MajorVersion).0 found"
                    # The currently published version is the current version
                    $stream = $_.OpenBinaryStream();
                }
                else
                {
                    $versions = $_.Versions;
                    $sourceContext.Load($versions);
                    $sourceContext.ExecuteQuery();

                    $versionLabel = [string]::Concat($_.MajorVersion, ".0");
                    Write-Verbose "Major version $versionLabel found"
                    $version = $versions | where { $_.VersionLabel -eq $versionLabel; } | select -First 1
                    if($null -eq $version)
                    {
                        Write-Error "Could not load version $versionLabel for file $($_.Name)"
                        continue
                    }
                    $sourceContext.Load($version);
                    $sourceContext.ExecuteQuery();
                    $stream = $version.OpenBinaryStream();
                }
            }
        }
        else
        {
            $stream = $_.OpenBinaryStream();
        }
        
        # Needs to be done
        $sourceContext.ExecuteQuery()
    
        $tmpStream = New-Object System.IO.MemoryStream
        $stream.Value.CopyTo($tmpStream)
        $res = $tmpStream.Seek(0,"Begin")
    
        $creationInfo = New-Object Microsoft.SharePoint.Client.FileCreationInformation
        $creationInfo.Overwrite = $true
        $creationInfo.ContentStream = $tmpStream
        $creationInfo.Url = $_.Name
    
        $upload = $target.Files.Add($creationInfo)
        $targetContext.Load($upload)
        $targetContext.ExecuteQuery()

        $tmpStream.Close()
        $stream.Value.Close()

        # Setting additional information
        if($TargetFolder -contains "/")
        {
            $tlName = $($TargetFolder -split "/")[0]
        }
        else
        {
            $tlName = $TargetFolder
        }
    }
    
    Write-Progress -Activity $Activity -status "Ready" -Completed
}

function CopyFolders{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourceRootFolder,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TargetRootFolder,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ConnectionSource,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ConnectionTarget,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NewRelativeSiteUrl,

        [Parameter(Mandatory=$false)]
        [switch]
        $IncludeFiles,

        [Parameter(Mandatory=$false)]
        [switch]
        $UseLatestMajorVersion
    )

    Write-Verbose "Getting items of type folder within $SourceRootFolder"
    $folder = Get-PnPFolderItem -ItemType Folder -FolderSiteRelativeUrl $SourceRootFolder -Connection $ConnectionSource

    $folder | where { $_.Name -ne "Forms" -and $_.Name -notmatch "Notizbuch*" }| ForEach-Object {
        Write-Verbose "Copying folder '$($_.Name)' and its child folders"
        Add-PnPFolder -Name $_.Name -Folder $TargetRootFolder -Connection $ConnectionTarget -ErrorAction SilentlyContinue
        $subFolder = "$SourceRootFolder/$($_.Name)"
        $newTargetFolder = "$TargetRootFolder/$($_.Name)"
        CopyFolders -SourceRootFolder $subFolder -TargetRootFolder $newTargetFolder -NewRelativeSiteUrl $NewRelativeSiteUrl `
                    -ConnectionSource $ConnectionSource -ConnectionTarget $ConnectionTarget -UseLatestMajorVersion:$UseLatestMajorVersion `
                    -IncludeFiles:$IncludeFiles
        if($IncludeFiles)
        {
            CopyAndMoveFile -SourceFolder $subFolder -TargetFolder $newTargetFolder -Activity "Copying" `
                            -ConnectionSource $ConnectionSource -ConnectionTarget $ConnectionTarget `
                            -NewRelativeSiteUrl $NewRelativeSiteUrl -UseLatestMajorVersion:$UseLatestMajorVersion
        }
    }
    
    if($IncludeFiles)
    {
        CopyAndMoveFile -SourceFolder $SourceRootFolder -TargetFolder $TargetRootFolder -Activity "Copying" `
                        -ConnectionSource $ConnectionSource -ConnectionTarget $ConnectionTarget `
                        -NewRelativeSiteUrl $NewRelativeSiteUrl -UseLatestMajorVersion:$UseLatestMajorVersion
    }
}

function Disconnect{
    Write-Verbose "Disconnecting"
    Disconnect-PnPOnline
    Write-Verbose "Disconnected"
}

##############################
#
# Main
#
##############################

$connectionSource = CheckCorrectConnection -urlToConnect $SourceSiteUrl
if($null -eq $connectionSource)
{
    Write-Error "Could not connect to $SourceSiteUrl"
    exit
}

$connectionTarget = CheckCorrectConnection -urlToConnect $TargetSiteUrl
if($null -eq $connectionTarget)
{
    Write-Error "Could not connect to $TargetSiteUrl"
    exit
}

$relativeSiteUrl = $($TargetSiteUrl -split '/')
$relativeSiteUrl = "/$($relativeSiteUrl[3])/$($relativeSiteUrl[4])"

CopyFolders -SourceRootFolder $SourceRootFolder -TargetRootFolder $TargetRootFolder -ConnectionSource $connectionSource `
            -ConnectionTarget $connectionTarget -NewRelativeSiteUrl $relativeSiteUrl -IncludeFiles:$IncludeFiles `
            -UseLatestMajorVersion:$UseLatestMajorVersion

Disconnect