Param(
    [Parameter(Mandatory = $true)]
    [string]
    $customerName,
    [Parameter(Mandatory = $false)]
    [bool]
    $createBackup = $true
)

Write-Output "Creating Edge profile for $customerName"

$profilePath = "profile-" + $customerName.replace(' ', '-')
$proc = Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList "--profile-directory=$profilePath --no-first-run --no-default-browser-check --flag-switches-begin --flag-switches-end --site-per-process" -PassThru

Write-Output "Profile $customerName created, wait 15 seconds before closing Edge"

Start-Sleep -Seconds 15 #it takes roughly 15 seconds to prepare the profile and write all files to disk.
Stop-Process -Name "msedge"

# Edit profile name
$localStateFile = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"

if ($createBackup) {
    $localStateBackUp = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State Backup"
    Copy-Item $localStateFile -Destination $localStateBackUp
}

$state = Get-Content -Raw $localStateFile
$json = $state | ConvertFrom-Json

$edgeProfile = $json.profile.info_cache.$profilePath

Write-Output "Found profile $profilePath"
Write-Output "Old profile name: $($edgeProfile.name)"

$edgeProfile.name = $customerName

Write-Output "Write profile name to local state: $($edgeProfile.name)"

# Only uncomment the next line if you know what you're doing!!
$json | ConvertTo-Json -Compress -Depth 100 | Out-File $localStateFile

Write-Output "Write profile name to registry: $($edgeProfile.name)"
Push-Location
Set-Location HKCU:\Software\Microsoft\Edge\Profiles\$profilePath
Set-ItemProperty . ShortcutName "$customerName"
Pop-Location

$preferenceSettings = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\$profilePath\Preferences"

if ($createBackup) {
    $preferenceSettingsBackup = "$Env:LOCALAPPDATA\Microsoft\Edge\User Data\$profilePath\Preferences Backup"
    Copy-Item $preferenceSettings -Destination $preferenceSettingsBackup
}

$preferences = Get-Content -Raw $preferenceSettings
$preferenceJson = $preferences | ConvertFrom-Json

if ($null -eq $preferenceJson.browser.show_hub_apps_tower) {
    Write-Output "Sidebar is not set and turned on by default, lets disable it"

    $preferenceJson.browser | add-member -Name "show_hub_apps_tower" -value $false -MemberType NoteProperty
}
else {
    $sideBarToggle = $preferenceJson.browser.show_hub_apps_tower
    Write-Output "Sidebar is set to: $sideBarToggle lets make it false"
    $preferenceJson.browser.show_hub_apps_tower = $false #disable side bar
}

if ($null -eq $preferenceJson.edge.vertical_tabs.collapsed) {
    Write-Output "Vertical tabs are turned off by default, lets enable it"

    $preferenceJson.edge.vertical_tabs | add-member -Name "collapsed" -value $true -MemberType NoteProperty
    $preferenceJson.edge.vertical_tabs | add-member -Name "first_opened2" -value $true -MemberType NoteProperty
    $preferenceJson.edge.vertical_tabs | add-member -Name "opened" -value $true -MemberType NoteProperty
}
else {
    $verticalTabs = $preferenceJson.edge.vertical_tabs.collapsed
    Write-Output "Vertical Tabs are set to: $verticalTabs, lets enable it"
    $preferenceJson.edge.vertical_tabs.collapsed = $true #enable vertical tabs
    $preferenceJson.edge.vertical_tabs.first_opened2 = $true #enable vertical tabs
    $preferenceJson.edge.vertical_tabs.opened = $true #enable vertical tabs
}

if ($null -eq $preferenceJson.local_browser_data_share.enabled) {
    Write-Output "Disable data share between profiles"
    $blockvalue =@"
    {
        "enabled": false,
        "index_last_cleaned_time": "0"
    }
"@

    $preferenceJson | add-member -Name "local_browser_data_share" -value (Convertfrom-Json $blockvalue) -MemberType NoteProperty
}
else {
    Write-Output "Disable data share between profiles"

    $preferenceJson.local_browser_data_share.enabled = $false; #disable sharing data between profiles
}

if ($null -eq $preferenceJson.edge_share) {
    Write-Output "Disable enhanced copy paste"
    $blockvalue =@"
    {
        "enhanced_copy_paste": {
            "default_url_format": 1,
            "enable_secondary_ecp": true
        }
    }
"@

    $preferenceJson | add-member -Name "edge_share" -value (Convertfrom-Json $blockvalue) -MemberType NoteProperty
}
else {
    Write-Output "Disable enhanced copy paste"

    $preferenceJson.edge_share.enhanced_copy_paste.default_url_format = 1; #disable enhanced copy paste
}

Write-Output "Write new settings to $($profilePath)"

# Only uncomment the next line if you know what you're doing!!
$preferenceJson | ConvertTo-Json -Compress -Depth 100 | Out-File $preferenceSettings

Write-Output "Done, you can start browsing with your new profile"