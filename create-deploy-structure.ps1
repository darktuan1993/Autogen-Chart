Clear-Host
Write-Host "==========================================="
Write-Host "++++ CREATE DEPLOY STRUCTURE TOOL +++++++++"
Write-Host "-------------------------------------------"
Write-Host "Author : Tuanbd7"
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

$staticFileContents = @{
    "README.md" = @'# Auto-generated deployment structure

This structure is created by `create-deploy-structure.ps1`. It contains the base Helm chart and Argo CD configuration required to deploy the application.
'@;
    "app-argocd/root-app.yaml" = @'apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ .Values.serviceName }}-root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: {{ .Values.git.repo }}
    targetRevision: {{ .Values.git.revision }}
    path: application/main-app
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: {{ .Values.namespace }}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
'@;
    "application/main-app/Chart.yaml" = @'apiVersion: v2
name: main-app
description: A Helm chart for deploying the main application.
type: application
version: 0.1.0
appVersion: "1.0.0"
'@;
    "application/main-app/templates/configmap.yaml" = @'{{- if .Values.configmap.enabled }}
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
'@;
    "application/main-app/templates/deployment.yaml" = @'apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.serviceName }}
  namespace: {{ .Values.namespace }}
  labels:
    app.kubernetes.io/name: {{ .Values.serviceName }}
    app.kubernetes.io/instance: {{ .Values.serviceName }}
spec:
  replicas: {{ .Values.deployment.replicas }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Values.serviceName }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ .Values.serviceName }}
        app.kubernetes.io/instance: {{ .Values.serviceName }}
    spec:
      containers:
        - name: {{ .Values.serviceName }}
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.port }}
          envFrom:
            - configMapRef:
                name: {{ .Values.serviceName }}-config
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          livenessProbe:
            {{- toYaml .Values.probes.liveness | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.probes.readiness | nindent 12 }}
'@;
    "application/main-app/templates/hpa.yaml" = @'{{- if .Values.hpa.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .Values.serviceName }}
  namespace: {{ .Values.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Values.serviceName }}
  minReplicas: {{ .Values.hpa.minReplicas }}
  maxReplicas: {{ .Values.hpa.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.hpa.targetCPUUtilizationPercentage }}
{{- end }}
'@;
    "application/main-app/templates/ingress.yaml" = @'{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Values.serviceName }}
  namespace: {{ .Values.namespace }}
  annotations:
{{- range $key, $value := .Values.ingress.annotations }}
    {{ $key }}: {{ $value | quote }}
{{- end }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  rules:
    - host: {{ .Values.ingress.host }}
      http:
        paths:
          - path: {{ .Values.ingress.path }}
            pathType: Prefix
            backend:
              service:
                name: {{ .Values.serviceName }}
                port:
                  number: {{ .Values.service.port }}
{{- end }}
'@;
    "application/main-app/templates/service.yaml" = @'apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.serviceName }}
  namespace: {{ .Values.namespace }}
  labels:
    app.kubernetes.io/name: {{ .Values.serviceName }}
    app.kubernetes.io/instance: {{ .Values.serviceName }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app.kubernetes.io/name: {{ .Values.serviceName }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
'@
}

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
        $null = New-Item -Path $fullFilePath -ItemType File -Force
        if ($staticFileContents.ContainsKey($relativeFile)) {
            Set-Content -Path $fullFilePath -Value $staticFileContents[$relativeFile] -Force
        }
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

Write-Output "CHART TEMPLATE DONE! $rootFolderPath"
