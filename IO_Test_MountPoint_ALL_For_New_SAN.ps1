$Capacity = @{Name="Capacity(GB)";expression={[math]::round(($_.Capacity/ 1073741824),2)}}
$FreespaceGB = @{Name="FreeSpace(GB)";expression={[math]::round(($_.FreeSpace / 1073741824),2)}}
$FreePerc = @{Name="Free(%)";expression={[math]::round(((($_.FreeSpace / 1073741824)/($_.Capacity / 1073741824)) * 100),0)}}

$volumes = Get-WmiObject  win32_volume | Where-object {$_.SystemVolume -eq $false}
$a = $volumes | Select  Name,$Capacity, $FreespaceGB, $FreePerc  
$Thread = "-t"+(((get-counter "\Processor(*)\% idle time").countersamples | select instancename).length -1)
$OutstandingIO = "-o16"
$CapacityParameter = "-c20G"
$Time = "-d5"
$NumberOfTests = 2
$blocksize = 8,64
$writeRead =0,100
$HowManyTimesWillTest=1
$IOTest="si","r"
$diskspdExe="C:\Diskspd\amd64fre"
 
 # Copy DiskSpd into current folder 
if ([System.IO.File]::Exists($diskspdExe + '\diskspd.exe')) {
	if(!([System.IO.File]::Exists((Resolve-Path .\).Path+'\diskspd.exe'))){
		Write-Host "Copying diskspd to local directory - $diskspdexe\diskspd.exe"
		Copy-Item "$diskspdExe\diskspd.exe", (Resolve-Path .\).Path
	}
}
	 
if ($PSVersionTable.PSVersion.Major -lt 3) {
    Write-host "Error: This script requires Powershell Version 3 and above to run correctly" -ForegroundColor Red
	return;
}

Write-Host "We found these Drives in your system";
foreach($vol in $a)
{
	Write-Host "Will perform this drive" $Disk = $vol.Name
}




Write-Host "It will take" ($a.count*$HowManyTimesWillTest*($Time.Replace("-d",""))) "second(s)"

write-host "TEST RESULTS (also logged in .\output.txt)" -foregroundcolor yellow

"Test N#, Drive, Operation, Access, Blocks, Run N#, IOPS, MB/sec, Latency ms, CPU %" >> ./output.txt
foreach($vol in $a)
{
	$Disk = $vol.Name.Substring(0,$vol.Name.Length-1)
	# Reset test counter
	$counter = 0 

	$IsDir = test-path -path "$Disk\TestDiskSpd"
	if ($IsDir -like "False")
	{
		new-item -itemtype directory -path "$Disk\TestDiskSpd\"
	}

	# Just a little security, in case we are working on a compressed drive ...
	#compact /u /s $Disk\TestDiskSpd\


	$Cleaning = test-path -path "$Disk\TestDiskSpd\testfile.dat"
	if ($Cleaning -eq "True")
	{
		remove-item $Disk\TestDiskSpd\testfile.dat
	}

	# Initialize outpout file
	$date = get-date

	# Begin Tests loops
	($blocksize) | % { 
		$BlockParameter = ("-b"+$_+"K")
		$Blocks = ("Blocks "+$_+"K")

		# We will do Read tests and Write tests
		($writeRead) | % {
			if ($_ -eq 0)
			{
				$IO = "Read"
			}
			elseif ($_ -eq 100)
			{
				$IO = "Write"
			}
			$WriteParameter = "-w"+$_

			# We will do random and sequential IO tests
			($IOTest) | % {
				if ($_ -eq "r")
				{
				$type = "Random"
				}
				elseif ($_ -eq "si")
				{
				$type = "Sequential"
				}

				$AccessParameter = "-"+$_
				(1..4) | % {
					# The test itself (finally !!)
	

	
					$result = .\diskspd.exe $CapacityParameter $Time $AccessParameter $WriteParameter $Thread $OutstandingIO $BlockParameter -h -L $Disk\TestDiskSpd\testfile.dat
	 




					# Now we will break the very verbose output of DiskSpd in a single line with the most important values
					foreach ($line in $result) {if ($line -like "total:*") { $total=$line; break } }
					foreach ($line in $result) {if ($line -like "avg.*") { $avg=$line; break } }
					$mbps = $total.Split("|")[2].Trim()
					$iops = $total.Split("|")[3].Trim()
					$latency = $total.Split("|")[4].Trim()
					$cpu = $avg.Split("|")[1].Trim()
					$counter = $counter + 1
	
					# A progress bar, for the fun
					#Write-Progress -Activity ".\diskspd.exe $CapacityParameter $Time $AccessParameter $WriteParameter $Thread $OutstandingIO $BlockParameter -h -L $Disk\TestDiskSpd\testfile.dat" -status "Test in progress" -percentComplete ($counter / $NumberofTests * 100)
					"Test $Counter,$Disk,$IO,$type,$Blocks,Run $_,$iops,$mbps,$latency,$cpu"  >> ./output.txt

					# We output a verbose format on screen
					"Test $Counter, $Disk, $IO, $type, $Blocks, Run $_, $iops iops, $mbps MB/sec, $latency ms, $cpu CPU"
				}
			}
		}
	}
}