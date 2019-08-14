<#
.SYNOPSIS
    Run's all Health Analyzer Jobs at once.
.DESCRIPTION
    Get's all Timer Job definitions for Health Analyzer Timer Jobs and triggers the RunNow()
.EXAMPLE
    PS C:\> .\Run-HealthAnalyzerTimerJobs.ps1
    Runs the jobs
.EXAMPLE
    PS C:\> .\Run-HealthAnalyzerTimerJobs.ps1 -OpenCentralAdministration
    Runs the jobs and opens central administration on the Timer Job Run Now page.
.PARAMETER OpenCentralAdministration
    Opens Central Administration after triggering all Health Analyzer Timer Jobs
.NOTES
    File Name  : Run-HealthAnalyzerTimerJobs.ps1
    Author     : Christoph Vollmann
#>

##############################
#
# Parameters
#
##############################

param(
    [switch]
    $OpenCentralAdministration
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

Write-Output "Getting Health Analyzer Timer Job definitions..."

$jobs = Get-SPTimerJob | ? { $_.Name -like "*-health-analysis-job" }

if (!$jobs -or $jobs.Count -eq 0) {
    Write-Error "Found no timerjobs."
    exit
}

Write-Output "Found $($jobs.Count) timer jobs. Calling RunNow on all of them..."

foreach ($job in $jobs) {
    Write-Output $job.Title
    $job.RunNow()
}

if ($OpenCentralAdministration) {
    Write-Output "Getting Central Admin URL..."
    $caUrl = Get-SPWebApplication -includecentraladministration | ? {$_.IsAdministrationWebApplication} | Select-Object -ExpandProperty Url
    
    Write-Output "Open IE with current timerjob status..."
    $ie = New-Object -com internetexplorer.application; 
    $ie.visible = $true; 
    $ie.navigate($caUrl + "/_admin/ServiceRunningJobs.aspx");
    
}

Write-Output "finished - timer jobs are probably still planned or running right now"
