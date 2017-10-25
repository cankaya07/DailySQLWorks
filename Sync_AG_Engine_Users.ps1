$Machines = @(Get-DbaAvailabilityGroup -SqlInstance TESTLSTR | select-object -expand AvailabilityReplicas) | select -uniq

foreach($Machine in $Machines)
{
	$selectedMachine = 	$Machine
	
	foreach($Machine2 in $Machines)
	{
		if($Machine2 -ne $selectedMachine)
		{
			Write-Host  Copy-SqlLogin -Source  $selectedMachine.ToString().Replace("[","").Replace("]","") -Destination $Machine2.ToString().Replace("[","").Replace("]","")
		}
	}
}

 
$Machines = "";