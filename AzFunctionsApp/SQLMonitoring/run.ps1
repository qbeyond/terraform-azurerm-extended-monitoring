<#
.SYNOPSIS
    Retrieving Monitoring Data and sending it to LAW.
.DESCRIPTION
    This script regularly checks SQL Servers for availability and sends the retrieved data to Log Analytics Workspace.
.EXAMPLE
#>

# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Warning "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Warning "PowerShell timer trigger function ran! TIME: $currentUTCtime"

# $sqlServer = Get-AzSqlServer
# foreach($server in $sqlServer) {

# }


# get sharedKey after LAW was created 
# body ?
$customerId = "baee5c0e-d4cc-4c2e-b92c-fea0cff04431" #"8ab860c4-fca0-44ab-8704-faf34748c6a3"
$sharedKey = "ITMCHcARStQZmdYKyZFf9rnr0qXrMBB1KNUjaVNiequGOyOEqRIHT2rTd1JR/Bdvyu4q3Fn7IEeMBDMfpx/whA=="
$logType = "MonitoringResources"

$body = @"
    [
        {
            "TimeGenerated": "$(Get-Date -Format o)",
            "TestField": "TestValue1",
            "AnotherField": "TestValue2"
        }
    ]
"@


# Create the function to create and post the request
function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType) {
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type"      = $logType;
        "x-ms-date"     = $rfc1123date;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode
}

try {
    Write-Output "Start to import Microsoft Resource Graph data to Log Analytics ..."
    # Submit the data to the API endpoint
    Post-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body (($result | ConvertTo-Json -Depth 10)) -logType $logType 
    Write-Output "Finished import Microsoft Resource Graph data to Log Analytics ..."
}
catch {
    throw "The script execution failed with Error `n`t $($($_.Exception).Message)"
}