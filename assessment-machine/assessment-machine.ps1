Import-Module ActiveDirectory

# Domain Information
$domainName = (Get-ADDomain).DNSRoot
$netbiosName = (Get-ADDomain).NetBIOSName
$forestLevel = (Get-ADForest).ForestMode
$domainControllersList = Get-ADDomainController -Filter *
$domainControllers = $domainControllersList.Count
$groups = (Get-ADGroup -Filter *).Count
$ouCount = (Get-ADOrganizationalUnit -Filter *).Count
$computers = (Get-ADComputer -Filter *).Count
$totalUsers = (Get-ADUser -Filter *).Count
$activeUsers = (Get-ADUser -Filter {Enabled -eq $true}).Count

# Operating System Count
$osCounts = Get-ADComputer -Filter * -Properties OperatingSystem | Group-Object -Property OperatingSystem | Select-Object Name, Count

# Inactive Users (180 days)
$cutoffDate = (Get-Date).AddDays(-180)
$inactiveUsersList = Get-ADUser -Filter * -Properties LastLogonDate, PasswordNeverExpires | Where-Object { $_.LastLogonDate -lt $cutoffDate }
$inactiveUsers = $inactiveUsersList.Count

# Admin Groups
$domainAdminsList = Get-ADGroupMember -Identity "Domain Admins" | Get-ADUser -Properties PasswordNeverExpires
$domainAdmins = $domainAdminsList.Count

$enterpriseAdminsList = Get-ADGroupMember -Identity "Enterprise Admins" | Get-ADUser -Properties PasswordNeverExpires
$enterpriseAdmins = $enterpriseAdminsList.Count

$schemaAdminsList = Get-ADGroupMember -Identity "Schema Admins" | Get-ADUser -Properties PasswordNeverExpires
$schemaAdmins = $schemaAdminsList.Count

# Users with Password Never Expires
$usersNoExpire = (Get-ADUser -Filter * -Properties PasswordNeverExpires | Where-Object { $_.PasswordNeverExpires -eq $true } | Measure-Object).Count

# Password Policy
$passwordPolicy = Get-ADDefaultDomainPasswordPolicy

# Summary Report
$report = [PSCustomObject]@{
    "Domain Name" = $domainName
    "NetBIOS" = $netbiosName
    "Forest Functional Level" = $forestLevel
    "Domain Controllers" = $domainControllers
    "Groups" = $groups
    "Organizational Units" = $ouCount
    "Computers" = $computers
    "Total Users" = $totalUsers
    "Active Users" = $activeUsers
    "Inactive Users (180 days)" = $inactiveUsers
    "Domain Admins" = $domainAdmins
    "Enterprise Admins" = $enterpriseAdmins
    "Schema Admins" = $schemaAdmins
    "Users with Password Never Expires" = $usersNoExpire
}

# Check if Import-Excel is installed
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Install-Module -Name ImportExcel -Scope CurrentUser -Force
}

# Import Module
Import-Module ImportExcel

# Export to Excel
$excelPath = "C:\Users\eversafe.leandro\Documents\github-cobaltone\reports\assessment-detailed.xlsx"
$report | Export-Excel -Path $excelPath -WorksheetName "Summary" -AutoSize -MoveToStart

# Domain Controllers Report
$domainControllersReport = $domainControllersList | Select-Object Name, OperatingSystem, Site
$domainControllersReport | Export-Excel -Path $excelPath -WorksheetName "Domain Controllers" -AutoSize

# Inactive Computers Report
$inactiveComputersReport = Get-ADComputer -Filter * -Properties LastLogonDate, OperatingSystem | Where-Object { $_.LastLogonDate -lt $cutoffDate } | Select-Object Name, OperatingSystem, LastLogonDate
$inactiveComputersReport | Export-Excel -Path $excelPath -WorksheetName "Inactive Computers" -AutoSize

# Operating Systems Report
$osCounts | Export-Excel -Path $excelPath -WorksheetName "Operating Systems" -AutoSize

# Inactive Users Report
$inactiveUsersReport = $inactiveUsersList | Select-Object Name, SamAccountName, LastLogonDate, PasswordNeverExpires
$inactiveUsersReport | Export-Excel -Path $excelPath -WorksheetName "Inactive Users" -AutoSize

# Domain Admins Report
$domainAdminsReport = $domainAdminsList | Select-Object Name, SamAccountName, PasswordNeverExpires
$domainAdminsReport | Export-Excel -Path $excelPath -WorksheetName "Domain Admins" -AutoSize

# Enterprise Admins Report
$enterpriseAdminsReport = $enterpriseAdminsList | Select-Object Name, SamAccountName, PasswordNeverExpires
$enterpriseAdminsReport | Export-Excel -Path $excelPath -WorksheetName "Enterprise Admins" -AutoSize

# Schema Admins Report
$schemaAdminsReport = $schemaAdminsList | Select-Object Name, SamAccountName, PasswordNeverExpires
$schemaAdminsReport | Export-Excel -Path $excelPath -WorksheetName "Schema Admins" -AutoSize

# Password Policy Report
$passwordPolicyReport = [PSCustomObject]@{
    "Complexity Enabled" = $passwordPolicy.ComplexityEnabled
    "Minimum Length" = $passwordPolicy.MinPasswordLength
    "Password History" = $passwordPolicy.PasswordHistoryCount
    "Lockout Threshold" = $passwordPolicy.LockoutThreshold
    "Lockout Duration (min)" = $passwordPolicy.LockoutDuration.TotalMinutes
    "Expiration Time (days)" = $passwordPolicy.MaxPasswordAge.Days
}
$passwordPolicyReport | Export-Excel -Path $excelPath -WorksheetName "Password Policy" -AutoSize

Write-Host "Report generated at $excelPath"
