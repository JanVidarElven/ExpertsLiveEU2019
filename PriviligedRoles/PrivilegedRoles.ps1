# Azure AD CmdLets for Privileged Roles

# Connect to Azure AD Tenant (Change to your Tenant)
Connect-AzureAD -TenantId elven.onmicrosoft.com

# Get Azure Privileged Resources
Get-AzureADMSPrivilegedResource -ProviderId AzureResources

# Group Count on Type (will cap on 200)
Get-AzureADMSPrivilegedResource -ProviderId AzureResources | Group-Object Type | Select-Object Count, Name

# Filter on Resource Group type or Subscription type
Get-AzureADMSPrivilegedResource -ProviderId AzureResources -Filter "Type eq 'resourcegroup'"
Get-AzureADMSPrivilegedResource -ProviderId AzureResources -Filter "Type eq 'subscription'"
# Filter on DisplayName
Get-AzureADMSPrivilegedResource -ProviderId AzureResources -Filter "DisplayName eq 'rg-vnet'"
Get-AzureADMSPrivilegedResource -ProviderId AzureResources -Filter "startswith(DisplayName,'rg-')"
# Get Specific Resource Id
Get-AzureADMSPrivilegedResource -ProviderId AzureResources -Id <your-id>

# Get Azure Privileged Resource Assignments
$myResource = Get-AzureADMSPrivilegedResource -ProviderId AzureResources -Filter "DisplayName eq '<your subscription/resource name'"
Get-AzureADMSPrivilegedRoleAssignment –ProviderId AzureResources –ResourceId $myResource.Id

# List User/Group object names for assignment
Get-AzureADMSPrivilegedRoleAssignment –ProviderId AzureResources –ResourceId $myResource.Id | % { Get-AzureADObjectByObjectId -ObjectIds $_.SubjectId} | Select ObjectId, DisplayName | FT
# List Resource names for assignment
Get-AzureADMSPrivilegedRoleAssignment –ProviderId AzureResources –ResourceId $myResource.Id | % { Get-AzureADMSPrivilegedRoleDefinition -ProviderId AzureResources -ResourceId $myResource.Id -Id $_.RoleDefinitionId} | Select Id, DisplayName

# Explore Role Settings
$myResourceId = (Get-AzureADMSPrivilegedResource -ProviderId AzureResources -Filter "DisplayName eq 'your resource name'").Id
$myResourceRoleId = (Get-AzureADMSPrivilegedRoleDefinition -ProviderId AzureResources -ResourceId $myResourceId -Filter "DisplayName eq 'Reader'").Id
$myResourceRoleSetting = Get-AzureADMSPrivilegedRoleSetting -ProviderId AzureResources -Filter "ResourceId eq '$myResourceId' and RoleDefinitionId eq '$myResourceRoleId'"
# Update Role Setting
$setting = New-Object Microsoft.Open.MSGraph.Model.AzureADMSPrivilegedRuleSetting
$setting.RuleIdentifier = "ExpirationRule"
# Default Setting = {"maximumGrantPeriod":"30.00:00:00","maximumGrantPeriodInMinutes":43200,"permanentAssignment":false}
$setting.Setting = '{"maximumGrantPeriod":"90.00.00.00","maximumGrantPeriodInMinutes":129600,"permanentAssignment":false}'
# Update role setting
Set-AzureADMSPrivilegedRoleSetting -ProviderId AzureResources -Id $myResourceRoleSetting.Id -ResourceId $myResourceRoleSetting.ResourceId -RoleDefinitionId $myResourceRoleSetting.RoleDefinitionId -AdminMemberSettings $setting

### FUNCTION Add Specified User to Privileged Role for Specified Resource
function Open-PIMAssignmentRequest {
    <#
    .SYNOPSIS
    This function is used to Open an Azure AD Privileged Role Assignement Request
    .DESCRIPTION
    This function is used to Open an Azure AD Privileged Role Assignement Request
    .EXAMPLE
    .NOTES
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $userUpn,
        [Parameter(Mandatory = $true)]
        $roleName,
        [Parameter(Mandatory = $true)]
        $resourceName,
        [Parameter(Mandatory = $false)]
        $targetEndDate            
    )

    # Set resource object variable
    $myResource = Get-AzureADMSPrivilegedResource -ProviderId AzureResources -Filter "DisplayName eq '$resourceName'"

    # Get role Id
    $myResourceRole = Get-AzureADMSPrivilegedRoleDefinition -ProviderId AzureResources -ResourceId $myResource.Id -Filter "DisplayName eq '$roleName'"

    # Get user id
    $myUser = Get-AzureADUser -ObjectId "$userUpn"

    # Set schedule
    $mySchedule = New-Object Microsoft.Open.MSGraph.Model.AzureADMSPrivilegedSchedule
        $mySchedule.Type = "Once"
        $mySchedule.StartDateTime = Get-Date
        If ($targetEndDate) {
            $ts = New-TimeSpan -Start $mySchedule.StartDateTime -End (Get-date -Date $targetEndDate)
            $mySchedule.EndDateTime = (Get-Date).AddDays($ts.TotalDays)
        }
        else {
            $mySchedule.EndDateTime = (Get-Date).AddDays(30)
        }

    # Create Assignment Request
    Open-AzureADMSPrivilegedRoleAssignmentRequest -ProviderId AzureResources -Schedule $mySchedule `
    -ResourceId $myResource.Id -RoleDefinitionId $myResourceRole.Id -SubjectId $myUser.ObjectId `
    -Reason ("Added " + $myUser.DisplayName + " as " + $myResourceRole.DisplayName) -AssignmentState "Active" -Type "AdminAdd"
    
}

### FUNKSJON Update Privileged Role Settings for Specified Resource and Role
function Set-PIMRoleSettings {
    <#
    .SYNOPSIS
    This function is used to Set Azure AD Privileged Role Settings for Resource Specified
    .DESCRIPTION
    This function is used to Set Azure AD Privileged Role Settings for Resource Specified
    .EXAMPLE
    .NOTES
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $roleName,
        [Parameter(Mandatory = $true)]
        $resourceName,        
        [Parameter(Mandatory=$false)]
        $roleAdminEligibleSettings,
        [Parameter(Mandatory=$false)]
        $roleAdminMemberSettings,
        [Parameter(Mandatory=$false)]
        $roleUserEligibleSettings,
        [Parameter(Mandatory=$false)]
        $roleUserMemberSettings
        )

    # Set Resource Object Variable
    $myResourceId = (Get-AzureADMSPrivilegedResource -ProviderId AzureResources -Filter "DisplayName eq '$resourceName'").Id

    # Get Role Id
    $myResourceRoleId = (Get-AzureADMSPrivilegedRoleDefinition -ProviderId AzureResources -ResourceId $myResourceId -Filter "DisplayName eq '$roleName'").Id

    # Get Role Settings
    $myResourceRoleSetting = Get-AzureADMSPrivilegedRoleSetting -ProviderId AzureResources -Filter "ResourceId eq '$myResourceId' and RoleDefinitionId eq '$myResourceRoleId'"
    
    # Update Role Settings as Specified
    If ($roleAdminEligibleSettings) {
        Set-AzureADMSPrivilegedRoleSetting -ProviderId AzureResources -Id $myResourceRoleSetting.Id -ResourceId $myResourceRoleSetting.ResourceId -RoleDefinitionId $myResourceRoleSetting.RoleDefinitionId -AdminEligibleSettings $roleAdminEligibleSettings
    }
    elseif ($roleAdminMemberSettings) {
        Set-AzureADMSPrivilegedRoleSetting -ProviderId AzureResources -Id $myResourceRoleSetting.Id -ResourceId $myResourceRoleSetting.ResourceId -RoleDefinitionId $myResourceRoleSetting.RoleDefinitionId -AdminMemberSettings $roleAdminMemberSettings
    }
    elseif ($roleUserEligbleSettings) {
        Set-AzureADMSPrivilegedRoleSetting -ProviderId AzureResources -Id $myResourceRoleSetting.Id -ResourceId $myResourceRoleSetting.ResourceId -RoleDefinitionId $myResourceRoleSetting.RoleDefinitionId -UserEligibleSettings $roleUserEligibleSettings
    }
    elseif ($roleUserMemberSettings ) {
        Set-AzureADMSPrivilegedRoleSetting -ProviderId AzureResources -Id $myResourceRoleSetting.Id -ResourceId $myResourceRoleSetting.ResourceId -RoleDefinitionId $myResourceRoleSetting.RoleDefinitionId -UserMemberSettings $roleUserMemberSettings
    }
    else {
        # If not submittet a role setting, just list existing
        $myResourceRoleSetting
    }
}

# Call Function to Open Assignment Request
Open-PIMAssignmentRequest -userUpn "<your-upn>" -roleName "Reader" -resourceName "<your-resource-name>" -targetEndDate "31.12.2019 23:59:59"

# Update Settings for Roles to example 3 months instead of default 1 month
$setting = New-Object Microsoft.Open.MSGraph.Model.AzureADMSPrivilegedRuleSetting
$setting.RuleIdentifier = "ExpirationRule"
$setting.Setting = '{"maximumGrantPeriod":"90.00.00.00","maximumGrantPeriodInMinutes":129600,"permanentAssignment":false}'
# Call Function for Update Role Setting for Specified Role and Resource
Set-PIMRoleSettings -roleName "Reader" -resourceName "<your-resource-name>" -roleAdminMemberSettings $setting
