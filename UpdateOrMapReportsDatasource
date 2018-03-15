$reports = Get-RsFolderContent -ReportServerUri http://prod-bldy-ssrs/ReportServer -Path "/EBakanlik/YerelYonetim" | where Name -eq "RuhsatOrnek4GSM1AcilmaIzniRaporuFormu" | Select Path

foreach($trp in  $reports)
{
    Write-Host $trp.Path
    $reportDataSourceName =  Get-RsItemDataSource -ReportServerUri http://prod-bldy-ssrs/ReportServer -RsItem $trp.Path | Select Name
    foreach($reportds in $reportDataSourceName)
    {
        Write-Host $reportds.Name
        Set-RsDataSourceReference -Path $trp.Path -DataSourceName $reportds.Name -DataSourcePath "/EBakanlik/YerelYonetim/YerelYonetim_RW"
    }
   
}
  
