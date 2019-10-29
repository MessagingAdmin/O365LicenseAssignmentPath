function Get-UserLicenseTypeDetails {
<#
.Synopsis
   Cmdlet to find out whether user has a license assigned by direct or inherited path.
.DESCRIPTION
   Cmdlet accepts the user UPN or output of 'Get-MSOLUser'cmdlet and returns information about whether user has any O365 license assigned.
   If license is assigned, output also shows the path of the license assignment(Direct/Inherited).
   If the license is inherited, cmdlet output shows the group name from which user has received the license.
.EXAMPLE
   Get-UserLicenseTypeDetails -UserEmail xxxx@abc.onmicrosoft.com 
    # This example will provide license information for a particular user
.EXAMPLE
   Get-Content Users.csv | Get-UserLicenseTypeDetails | Export-csv Licenseinfo.csv
   # In this example, you import a list of users from a csv file which has no headers, just a list of user email addresses. 
   # Output is then exported to another csv file
.EXAMPLE
   Get-MSOLUser -All | Get-UserLicenseTypeDetails 
    # This example will pull a list of all users in Azure Active Directory and then get license information for each of them
.EXAMPLE
   Get-MSOLUser -All | Where isLicensed -eq $true | Get-UserLicenseTypeDetails 
    # This example will pull a list of all users in Azure Active Directory, filter out unlicensed users and then get license information for each of them
.INPUTS
   User Principal Name of users  -or
   Object of class [Microsoft.Online.Administration.User]
.OUTPUTS
   Object with License information details
.NOTES
   version 1.2.2 - 29/10/2019
   All rights reserved (c) 2019 Rajiv Pasalkar
.COMPONENT
   This cmdlet belongs to Office 365 administration module
#>
    
    param(
        # List of users (provide UserPrincipalName)
        [Parameter(Mandatory = $true,
        ParameterSetName = "WithEmailAddress",
        Position = 0,
        ValueFromPipeline=$true)]
        [string]
        $UserEmail,
        # List of users (accepts output of Get-MSOLUser cmdlet)
        [Parameter(Mandatory = $true,
        ParameterSetName = "WithMSOLUser",
        Position = 0,
        ValueFromPipeline=$true)]
        [Microsoft.Online.Administration.User]
        $MSOLUser
    )
    Begin{
        $UserLicenseDetail = @() #Empty that will store all the output
    }
    Process{
        If($UserEmail){
            $UserInfo = Get-MsolUser -UserPrincipalName $UserEmail
        }
        else {
            $UserInfo = $MSOLUser
        }
        If ($UserInfo.Licenses.count -gt 0){
            #Process further if user has any license assigned
            foreach($license in $UserInfo.Licenses){
                #gather details about each individual license
                $LicenseName = $license.AccountSkuId
                If($license.GroupsAssigningLicense.Count -eq 0){
                    #If the license is not inherited from any group
                    $AssignmentPath = "Direct"
                }
                else{
                    
                    #When license is inherited
                    foreach($groupid in $license.GroupsAssigningLicense){
                        #Checking each object id, if the id is same as user's object id, there is duplication of license assignment, else capture all the group names
                        $AssignmentPath = "Inherited"
                        If($groupid -ieq $UserInfo.ObjectId) {
                            If ($license.GroupsAssigningLicense.Count -eq 1){
                                $AssignmentPath = "Direct"     
                            }
                            Else {
                                $AssignmentPath += " + Direct"
                            }
                            break
                        }
                        #Capture group names
                        $GroupNames += Get-MsolGroup -ObjectId $groupid | Select-Object -ExpandProperty DisplayName
                    }
                }
                $UserLicenseDetail += [PSCustomObject]@{
                    'DisplayName' = $UserInfo.DisplayName
                    'UserPrincipalName' = $UserInfo.UserPrincipalName
                    'isLicensed' = $UserInfo.isLicensed
                    'LicenseCount' = $UserInfo.Licenses.count
                    'LicenseName' = $LicenseName
                    'AssignmentPath' = $AssignmentPath
                    'LicensedGroups'= $GroupNames
                }
                $GroupNames = ""
            }
        }
    }
    End{
        return $UserLicenseDetail
    }
}

