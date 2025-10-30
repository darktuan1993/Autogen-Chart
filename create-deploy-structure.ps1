param(
    [Parameter(Mandatory = $false)]
    [string]$ApplicationName
)

if (-not $ApplicationName) {
    $ApplicationName = Read-Host -Prompt "Nhập tên ứng dụng"
}

if (-not $ApplicationName) {
    Write-Error "Tên ứng dụng không được để trống."
    exit 1
}

$rootFolderName = "$ApplicationName-deploy"
$rootFolderPath = Join-Path -Path (Get-Location) -ChildPath $rootFolderName

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

$files = @(
    "README.md",
    "app-argocd/root-app.yaml",
    "app-argocd/service/backend.yaml",
    "app-argocd/service/xxxxx.yaml",
    "app-argocd/worker/worker-xxxx.yaml",
    "app-argocd/worker/worker-xx11.yaml",
    "application/main-app/Chart.yaml",
    "application/main-app/templates/configmap.yaml",
    "application/main-app/templates/deployment.yaml",
    "application/main-app/templates/hpa.yaml",
    "application/main-app/templates/xxxx.yaml",
    "application/main-app/templates/ingress.yaml",
    "application/main-app/templates/service.yaml",
    "application/main-app/values/service/values-backend.yaml",
    "application/main-app/values/worker/worker-xxxx.yaml"
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

foreach ($relativeFile in $files) {
    $fullFilePath = Join-Path -Path $rootFolderPath -ChildPath $relativeFile
    if (-not (Test-Path -Path $fullFilePath)) {
        $null = New-Item -Path $fullFilePath -ItemType File
    }
}

Write-Output "Đã tạo cấu trúc thư mục tại: $rootFolderPath"
