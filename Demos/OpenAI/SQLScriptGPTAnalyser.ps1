# Authenticate to the OpenAI API
Write-Host "Authenticating to OpenAI API"
$apiKey = "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"

# Set the path to the directory containing the SQL scripts
$sqlScriptDirectory = "C:\Users\Chris Unwin\Documents\flyway-commandline-8.5.2-windows-x64\flyway-8.5.2\sql"

# Get the list of SQL scripts in the directory
Write-Host "Getting list of SQL scripts"
$sqlScriptFiles = Get-ChildItem $sqlScriptDirectory -Filter *.sql

# Loop through each SQL script
Write-Host "Parsing SQL scripts and generating descriptions"
foreach ($sqlScript in $sqlScriptFiles) {
  try {
    # Read the contents of the SQL script
    $sqlScriptContents = Get-Content $sqlScript.FullName

    # Use the OpenAI API to generate a description of the script
    $requestBody = @{
      model = "text-davinci-003"
      prompt = "Describe the purpose of the following SQL script: $($sqlScriptContents)"
      max_tokens = 126
    }
    $jsonBody = ConvertTo-Json $requestBody
    $description = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/completions" -Headers @{
      "Authorization" = "Bearer $apiKey"
      "Content-Type" = "application/json"
    } -Body $jsonBody

    # Write the description to the console
    Write-Host "Description for $($sqlScript.Name): $($description.choices[0].text)"
  } catch {
    Write-Host "An error occurred while processing $($sqlScript.Name): $($_.Exception.Message)"
  }
}
