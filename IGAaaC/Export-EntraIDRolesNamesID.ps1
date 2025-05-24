try {
    $message = "[$($MyInvocation.MyCommand.Name)]: "
    $roles = Get-MgRoleManagementDirectoryRoleDefinition
    $roles | Select-Object DisplayName, Id | sort-Object DisplayName | Format-Table -AutoSize
    $roles | Select-Object DisplayName, Id | sort-Object DisplayName | Export-Csv -Path "EntraIDRolesNamesId.csv" -NoTypeInformation
        Write-Host "[$message]: " -NoNewline
        Write-Host "🔐 Entra ID Roles retrieved successfully. CSV saved to EntraIDRoles.csv." -ForegroundColor Green
}
catch {
    Write-Error $_
}