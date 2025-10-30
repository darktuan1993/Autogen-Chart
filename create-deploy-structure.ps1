$ApplicationName = Read-Host -Prompt "Nhập tên ứng dụng"

if (-not $ApplicationName) {
    Write-Error "Tên ứng dụng không được để trống."
    exit 1
}

$rootFolderName = "$ApplicationName-deploy"
$rootFolderPath = Join-Path -Path (Get-Location) -ChildPath $rootFolderName

$serviceNamesInput = Read-Host -Prompt "Nhập danh sách service (ngăn cách bởi dấu phẩy, để trống nếu không có)"
$workerNamesInput = Read-Host -Prompt "Nhập danh sách worker (ngăn cách bởi dấu phẩy, để trống nếu không có)"

function Get-NameList {
    param (
        [string]$Input
    )

    if (-not $Input) {
        return @()
    }

    return $Input.Split(",") |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

$serviceNames = Get-NameList -Input $serviceNamesInput
$workerNames = Get-NameList -Input $workerNamesInput

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
    New-Item -Path $rootFolderPath -ItemType Directory | Out-Null
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

Write-Output "Đã tạo cấu trúc thư mục tại: $rootFolderPath"
