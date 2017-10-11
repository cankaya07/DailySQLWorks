$Capacity = @{Name="Capacity(GB)";expression={[math]::round(($_.Capacity/ 1073741824),2)}}
$FreespaceGB = @{Name="FreeSpace(GB)";expression={[math]::round(($_.FreeSpace / 1073741824),2)}}
$FreePerc = @{Name="Free(%)";expression={[math]::round(((($_.FreeSpace / 1073741824)/($_.Capacity / 1073741824)) * 100),0)}}

$volumes = Get-WmiObject  win32_volume | Where-object {$_.DriveLetter -eq $null -and $_.SystemVolume -eq $false}
$a = $volumes | Select  Name,$Capacity, $FreespaceGB, $FreePerc  

foreach($vol in $a)
{
    $Disk = $vol.Name
    # Reset test counter
    $counter = 0
    # Use 1 thread / core


    $Thread = "-t"+(((get-counter "\Processor(*)\% idle time").countersamples | select instancename).length -1)
    $Thread
 


    # Set time in seconds for each run


    # 10-120s is fine


    $Time = "-d1"


 


    # Outstanding IOs


    # Should be 2 times the number of disks in the RAID


    # Between  8 and 16 is generally fine


    $OutstandingIO = "-o16"


 


    # Disk preparation


    # Delete testfile.dat if it exists


    # The test will use all free space -2GB


 


    $IsDir = test-path -path "$Disk\TestDiskSpd"


    $isdir


    if ($IsDir -like "False"){new-item -itemtype directory -path "$Disk\TestDiskSpd\"}


    # Just a little security, in case we are working on a compressed drive ...


    compact /u /s $Disk\TestDiskSpd\


 


    $Cleaning = test-path -path "$Disk\TestDiskSpd\testfile.dat"


    if ($Cleaning -eq "True")
    {"Removing current testfile.dat from drive"


      remove-item $Disk\TestDiskSpd\testfile.dat
        Write-Host $vol.Name
    }
 


$Capacity = $vol.'Capacity(GB)' - 2


$CapacityParameter = "-c20G"


if ($vol.'FreeSpace(GB)' -lt "4")


{


       "Not enough space on the Disk "+$Disk+" ! More than 4GB needed"


       


}


 


write-host "You are about to test $Disk which has "+$vol.'FreeSpace(GB)'+" GB free, "
 

 


"   "


"Initialization can take some time, we are generating a $vol.'Capacity(GB)' GB file..."


"  "


 


 


# Initialize outpout file


$date = get-date


 


# Add the tested disk and the date in the output file


"Disque $disk, $date" >> ./output.txt


 


# Add the headers to the output file


“Test N#, Drive, Operation, Access, Blocks, Run N#, IOPS, MB/sec, Latency ms, CPU %" >> ./output.txt


 


# Number of tests


# Multiply the number of loops to change this value


# By default there are : (4 blocks sizes) X (2 for read 100% and write 100%) X (2 for Sequential and Random) X (4 Runs of each)


$NumberOfTests = 64


 


"  "


write-host "TEST RESULTS (also logged in .\output.txt)" -foregroundcolor yellow


 


# Begin Tests loops


 


# We will run the tests with 4K, 8K, 64K and 512K blocks


(4,8,64,512) | % { 


$BlockParameter = ("-b"+$_+"K")


$Blocks = ("Blocks "+$_+"K")


 


# We will do Read tests and Write tests


  (0,100) | % {


      if ($_ -eq 0){$IO = "Read"}


      if ($_ -eq 100){$IO = "Write"}


      $WriteParameter = "-w"+$_


 


# We will do random and sequential IO tests


  ("r","si") | % {


      if ($_ -eq "r"){$type = "Random"}


      if ($_ -eq "si"){$type = "Sequential"}


      $AccessParameter = "-"+$_


 


# Each run will be done 4 times


  (1..4) | % {


     


      # The test itself (finally !!)


        $result = .\diskspd.exe $CapacityParameter $Time $AccessParameter $WriteParameter $Thread $OutstandingIO $BlockParameter -h -L $Disk\TestDiskSpd\testfile.dat
        Write-Host .\diskspd.exe $CapacityParameter $Time $AccessParameter $WriteParameter $Thread $OutstandingIO $BlockParameter -h -L $Disk\TestDiskSpd\testfile.dat

     


      # Now we will break the very verbose output of DiskSpd in a single line with the most important values


      foreach ($line in $result) {if ($line -like "total:*") { $total=$line; break } }


      foreach ($line in $result) {if ($line -like "avg.*") { $avg=$line; break } }


      $mbps = $total.Split("|")[2].Trim()


      $iops = $total.Split("|")[3].Trim()


      $latency = $total.Split("|")[4].Trim()


      $cpu = $avg.Split("|")[1].Trim()


      $counter = $counter + 1


 


      # A progress bar, for the fun


      Write-Progress -Activity ".\diskspd.exe $CapacityParameter $Time $AccessParameter $WriteParameter $Thread $OutstandingIO $BlockParameter -h -L $Disk\TestDiskSpd\testfile.dat" -status "Test in progress" -percentComplete ($counter / $NumberofTests * 100)


     


      # Remove comment to check command line ".\diskspd.exe $CapacityParameter $Time $AccessParameter $WriteParameter $Thread -$OutstandingIO $BlockParameter -h -L $Disk\TestDiskSpd\testfile.dat"


     


      # We output the values to the text file


      “Test $Counter,$Disk,$IO,$type,$Blocks,Run $_,$iops,$mbps,$latency,$cpu"  >> ./output.txt


 


      # We output a verbose format on screen


      “Test $Counter, $Disk, $IO, $type, $Blocks, Run $_, $iops iops, $mbps MB/sec, $latency ms, $cpu CPU"


}


}


}


}
}


 