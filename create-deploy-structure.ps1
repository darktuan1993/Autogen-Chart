Clear-Host
Write-Host "==========================================="
Write-Host "++++ CREATE DEPLOY STRUCTURE TOOL +++++++++"
Write-Host "-------------------------------------------"
Write-Host "Author : Tuanbd"
Write-Host "Version: 1.0"
Write-Host "==========================================="
Write-Host ""

$ApplicationName = Read-Host -Prompt "APPLICATION NAME"

if (-not $ApplicationName) {
    Write-Error "NON"
    exit 1
}

$rootFolderName = "$ApplicationName-deploy"

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$rootFolderPath = Join-Path -Path $scriptRoot -ChildPath $rootFolderName

# Reference the variable so it's used (avoids "assigned but never used" warnings)
Write-Output "Root folder path: $rootFolderPath"

$serviceNamesInput = Read-Host -Prompt "Input service names (comma-separated, leave empty if none)"
$workerNamesInput = Read-Host -Prompt "Input worker names (comma-separated, leave empty if none)"

function Get-NameList {
    param (
        [string]$NameListInput
    )

    if (-not $NameListInput) {
        return @()
    }

    return $NameListInput.Split(",") |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

$serviceNames = Get-NameList -NameListInput $serviceNamesInput
$workerNames = Get-NameList -NameListInput $workerNamesInput

# ✅ In ra đúng danh sách
if ($serviceNames.Count -gt 0) {
    Write-Output "SERVICE NAMES: $($serviceNames -join ', ')"
}
else {
    Write-Output "SERVICE NAMES: (none)"
}

if ($workerNames.Count -gt 0) {
    Write-Output "WORKER NAMES: $($workerNames -join ', ')"
}
else {
    Write-Output "WORKER NAMES: (none)"
}


$directories = @(
    "app-argocd",
    "app-argocd/service",
    "app-argocd/worker",
    "application",
    "application/main-app",
    "application/main-app/templates",
    "application/main-app/values",
    "application/main-app/values/service",
    "application/main-app/values/worker",
    "application/other-app"
)

$staticFiles = @(
    "README.md",
    "app-argocd/root-app.yaml",
    "application/main-app/Chart.yaml",
    "application/main-app/templates/configmap.yaml",
    "application/main-app/templates/deployment.yaml",
    "application/main-app/templates/hpa.yaml",
    "application/main-app/templates/ingress.yaml",
    "application/main-app/templates/service.yaml"
)

if (-not (Test-Path -Path $rootFolderPath)) {
    New-Item -Path $rootFolderPath -ItemType Directory -Force | Out-Null
}

foreach ($relativeDir in $directories) {
    $fullDirPath = Join-Path -Path $rootFolderPath -ChildPath $relativeDir
    if (-not (Test-Path -Path $fullDirPath)) {
        New-Item -Path $fullDirPath -ItemType Directory | Out-Null
    }
}

foreach ($relativeFile in $staticFiles) {
    $fullFilePath = Join-Path -Path $rootFolderPath -ChildPath $relativeFile
    if (-not (Test-Path -Path $fullFilePath)) {
        $null = New-Item -Path $fullFilePath -ItemType File
    }
}

$configMapTemplatePath = Join-Path -Path $rootFolderPath -ChildPath "application/main-app/templates/configmap.yaml"
$configMapTemplateContent = @'
{{- if .Values.configmap.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.serviceName }}-config
  namespace: {{ .Values.namespace }}
  labels:
    app.kubernetes.io/name: {{ .Values.serviceName }}
    app.kubernetes.io/instance: {{ .Values.serviceName }}
data:
{{- range $key, $value := .Values.configmap.data }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
'@

Set-Content -Path $configMapTemplatePath -Value $configMapTemplateContent -Encoding UTF8

foreach ($serviceName in $serviceNames) {
    $serviceFile = "app-argocd/service/$serviceName.yaml"
    $serviceValuesFile = "application/main-app/values/service/values-$serviceName.yaml"

    foreach ($relativeFile in @($serviceFile, $serviceValuesFile)) {
        $fullFilePath = Join-Path -Path $rootFolderPath -ChildPath $relativeFile
        if (-not (Test-Path -Path $fullFilePath)) {
            $null = New-Item -Path $fullFilePath -ItemType File
        }
    }
}

foreach ($workerName in $workerNames) {
    $workerFile = "app-argocd/worker/$workerName.yaml"
    $workerValuesFile = "application/main-app/values/worker/values-$workerName.yaml"

    foreach ($relativeFile in @($workerFile, $workerValuesFile)) {
        $fullFilePath = Join-Path -Path $rootFolderPath -ChildPath $relativeFile
        if (-not (Test-Path -Path $fullFilePath)) {
            $null = New-Item -Path $fullFilePath -ItemType File
        }
    }
}

Write-Output "CHART TEMPLATE DONE! $rootFolderPath"
