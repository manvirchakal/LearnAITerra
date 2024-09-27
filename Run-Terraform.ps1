# Load environment variables from .env file
Get-Content .\.env | ForEach-Object {
    $name, $value = $_.split('=')
    if ([string]::IsNullOrWhiteSpace($name) -or $name.StartsWith("#")) {
        continue
    }
    Set-Item -Path Env:$name -Value $value
}

# Run Terraform with all arguments passed to this script
terraform $args