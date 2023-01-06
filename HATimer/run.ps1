# Input bindings are passed in via param block.
param($Timer)
Write-Output -InputObject "HA NVA timer trigger function executed at:$(Get-Date)"

$VMFW1Name = $env:FW1NAME      # Set the Name of the primary NVA firewall
$VMFW2Name = $env:FW2NAME      # Set the Name of the secondary NVA firewall
$FW1RGName = $env:FWR1GNAME    # Set the ResourceGroup that contains FW1
$FW2RGName = $env:FWR2GNAME    # Set the ResourceGroup that contains FW2
$Monitor = $env:FWMONITOR      # "VMStatus" or "TCPPort" are valid values
$HubName = $env:HUBNAME
#$RouteTableName = $env:ROUTETABLENAME
$FailOver = $True              # Trigger to enable fail-over to secondary NVA firewall if primary NVA firewall drops when active
$FailBack = $True              # Trigger to enable fail-back to primary NVA firewall is secondary NVA firewall drops when active
$IntTries = $env:FWTRIES       # Number of Firewall tests to try 
$IntSleep = $env:FWDELAY       # Delay in seconds between tries
$VirtualHubName = "UK_vWAN_Hub"
$VirtualHubResourceGroupName = "UK_Network"
$RouteTableName = "UK-SD-WAN-1"
$RouteName = "SD-WAN-1"

Function Test-VMStatus ($VM, $FWResourceGroup) {
  $VMDetail = Get-AzVM -ResourceGroupName $FWResourceGroup -Name $VM -Status
  foreach ($VMStatus in $VMDetail.Statuses) { 
    $Status = $VMStatus.code
      
    if ($Status.CompareTo('PowerState/running') -eq 0) {
      Return $False
    }
  }
  Return $True  
}

Function Start-Failover {  
  # Bypassing conditions and editing the routes

  Write-Output -InputObject "Starting failover"
  Set-AzContext -Subscription $env:SUBSCRIPTIONID        
    
  
  $firewall2 = Get-AzVirtualHubVnetConnection -Name "Meraki-vmx2" -ResourceGroupName $VirtualHubResourceGroupName -ParentResourceName $VirtualHubName
  $route2 = New-AzVHubRoute -Name $RouteName -Destination @("192.168.128.0/24", "10.5.5.0/24") -DestinationType "CIDR" -NextHop $firewall2.Id -NextHopType "ResourceId"
  Update-AzVHubRouteTable -ResourceGroupName $VirtualHubResourceGroupName -VirtualHubName $VirtualHubName -Name $RouteTableName -Route @($route2)

  Write-Output -InputObject "Failover done"

  
  <#foreach ($SubscriptionID in $Script:ListOfSubscriptionIDs) {        

    
    
    $RTable = @()
    $TagValue = $env:FWUDRTAG  
    $Res = Get-AzResource -TagName nva_ha_udr -TagValue $TagValue

    foreach ($RTable in $Res) {                  

      
      $Table = Get-AzVHubRouteTable -ResourceGroupName $VirtualHubResourceGroupName -Name $RouteTableName -VirtualHubName $VirtualHubName

      foreach ($RouteName in $Table.Routes) {
        Write-Output -InputObject "Updating route table $RTable.Name"        

        

        for ($i = 0; $i -lt $PrimaryInts.count; $i++) {
          if ($RouteName.NextHopIpAddress -eq $SecondaryInts[$i]) {
            Write-Output -InputObject 'Secondary NVA is already ACTIVE' 
            
          }
          elseif ($RouteName.NextHopIpAddress -eq $PrimaryInts[$i]) {
            # Code created by Mehrin
            Write-Output -InputObject 'Start failover'
            $firewall2 = Get-AzVirtualHubVnetConnection -Name "Meraki-vmx2" -ResourceGroupName $VirtualHubResourceGroupName -ParentResourceName $VirtualHubName
            $route2 = New-AzVHubRoute -Name $RouteName -Destination @("192.168.128.0/24", "10.5.5.0/24") -DestinationType "CIDR" -NextHop $firewall2.Id -NextHopType "ResourceId"
            Update-AzVHubRouteTable -ResourceGroupName $VirtualHubResourceGroupName -VirtualHubName $VirtualHubName -Name $RouteTableName -Route @($route2)
          }
          else {
            Write-Output -InputObject 'No match found'
            Write-Output -InputObject "#Next Hop IP is: $RouteName.NextHopIpAddress #Primary interface IP is: $PrimaryInts[$i]"
          }
        }

  }              
}
  }  #>
}

Function Start-Failback {
  # Bypassing conditions and editing the routes
  Write-Output -InputObject "Starting failover"
  Set-AzContext -Subscription $env:SUBSCRIPTIONID        

  $firewall1 = Get-AzVirtualHubVnetConnection -Name "Meraki-vmx1" -ResourceGroupName $VirtualHubResourceGroupName -ParentResourceName $VirtualHubName
  $route1 = New-AzVHubRoute -Name $RouteName -Destination @("192.168.128.0/24", "10.5.5.0/24") -DestinationType "CIDR" -NextHop $firewall1.Id -NextHopType "ResourceId"
  Update-AzVHubRouteTable -ResourceGroupName $VirtualHubResourceGroupName -VirtualHubName $VirtualHubName -Name $RouteTableName -Route @($route1)

  Write-Output -InputObject "Failback done"
  
  <#foreach ($SubscriptionID in $Script:ListOfSubscriptionIDs) {                            
    $RTable = @()
    $TagValue = $env:FWUDRTAG    
    $Res = Get-AzResource -TagName nva_ha_udr -TagValue $TagValue

    foreach ($RTable in $Res) {            
      $Table = Get-AzVHubRouteTable -ResourceGroupName $VirtualHubResourceGroupName -Name $RouteTableName -VirtualHubName $VirtualHubName

      foreach ($RouteName in $Table.Routes) {
        Write-Output -InputObject "Updating route table $RTable.Name"                

        for ($i = 0; $i -lt $PrimaryInts.count; $i++) {
          if ($RouteName.NextHopIpAddress -eq $PrimaryInts[$i]) {
            Write-Output -InputObject 'Primary NVA is already ACTIVE' 
          
          }
          elseif ($RouteName.NextHopIpAddress -eq $SecondaryInts[$i]) {
            Write-Output -InputObject 'Start failback'
            $firewall1 = Get-AzVirtualHubVnetConnection -Name "Meraki-vmx1" -ResourceGroupName $VirtualHubResourceGroupName -ParentResourceName $VirtualHubName
            $route1 = New-AzVHubRoute -Name $RouteName -Destination @("192.168.128.0/24", "10.5.5.0/24") -DestinationType "CIDR" -NextHop $firewall1.Id -NextHopType "ResourceId"
            Update-AzVHubRouteTable -ResourceGroupName $VirtualHubResourceGroupName -VirtualHubName $VirtualHubName -Name $RouteTableName -Route @($route1)
            
          }  
        }

  }        
}
  }#>
}

Function Get-FWInterfaces {
  $Nics = Get-AzNetworkInterface | Where-Object -Property VirtualMachine -NE -Value $Null
  $VMS1 = Get-AzVM -Name $VMFW1Name -ResourceGroupName $FW1RGName
  $VMS2 = Get-AzVM -Name $VMFW2Name -ResourceGroupName $FW2RGName

  foreach ($Nic in $Nics) {

    if (($Nic.VirtualMachine.Id -EQ $VMS1.Id) -Or ($Nic.VirtualMachine.Id -EQ $VMS2.Id)) {
      $VM = $VMS | Where-Object -Property Id -EQ -Value $Nic.VirtualMachine.Id
      $Prv = $Nic.IpConfigurations | Select-Object -ExpandProperty PrivateIpAddress  

      if ($VM.Name -eq $VMFW1Name) {
        $Script:PrimaryInts += $Prv
      }
      elseif ($VM.Name -eq $vmFW2Name) {
        $Script:SecondaryInts += $Prv
      }

    }

  }
}

Function Get-Subscriptions {
  Write-Output -InputObject "Enumerating all subscriptins ..."
  $Script:ListOfSubscriptionIDs = (Get-AzSubscription).SubscriptionId  
  Write-Output -InputObject $Script:ListOfSubscriptionIDs
}

#--------------------------------------------------------------------------
# Main code block for Azure function app                       
#--------------------------------------------------------------------------
$Password = ConvertTo-SecureString $env:SP_PASSWORD -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($env:SP_USERNAME, $Password)
Connect-AzAccount -ServicePrincipal -TenantId $env:TENANTID -Credential $Credential
Set-AzContext -Subscription $env:SUBSCRIPTIONID

$Script:PrimaryInts = @()
$Script:SecondaryInts = @()
$Script:ListOfSubscriptionIDs = @()

# Check NVA firewall status $intTries with $intSleep between tries

$CtrFW1 = 0
$CtrFW2 = 0
$FW1Down = $True
$FW2Down = $True

$VMS = Get-AzVM

Get-Subscriptions
Get-FWInterfaces

# Test primary and secondary NVA firewall status 

For ($Ctr = 1; $Ctr -le $IntTries; $Ctr++) {
  
  if ($Monitor -eq 'VMStatus') {
    $FW1Down = Test-VMStatus -VM $VMFW1Name -FwResourceGroup $FW1RGName
    $FW2Down = Test-VMStatus -VM $VMFW2Name -FwResourceGroup $FW2RGName
  } 

  Write-Output -InputObject "Pass $Ctr of $IntTries - FW1Down is $FW1Down, FW2Down is $FW2Down"

  if ($FW1Down) {
    $CtrFW1++
  }

  if ($FW2Down) {
    $CtrFW2++
  }

  Write-Output -InputObject "Sleeping $IntSleep seconds"
  Start-Sleep $IntSleep
}

# Reset individual test status and determine overall NVA firewall status

$FW1Down = $False
$FW2Down = $False

if ($CtrFW1 -eq $intTries) {
  $FW1Down = $True
}

if ($CtrFW2 -eq $intTries) {
  $FW2Down = $True
}

# Failover or failback if needed

if (($FW1Down) -and -not ($FW2Down)) {
  if ($FailOver) {
    Write-Output -InputObject 'FW1 Down - Failing over to FW2'
    Start-Failover 
  }
}
elseif (-not ($FW1Down) -and ($FW2Down)) {
  if ($FailBack) {
    Write-Output -InputObject 'FW2 Down - Failing back to FW1'
    Start-Failback
  }
  else {
    Write-Output -InputObject 'FW2 Down - Failing back disabled'
  }
}
elseif (($FW1Down) -and ($FW2Down)) {
  Write-Output -InputObject 'Both FW1 and FW2 Down - Manual recovery action required'  
}
else {
  Write-Output -InputObject 'Both FW1 and FW2 Up - No action is required'
}

