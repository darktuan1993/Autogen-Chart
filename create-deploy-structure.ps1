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

### CHART METADATA CONTENT
$chartTemplatePath = Join-Path -Path $rootFolderPath -ChildPath "application/main-app/Chart.yaml"
$chartTemplateContent = @"
apiVersion: v2
name: $ApplicationName
description: Minimal Helm chart without helpers
type: application
version: 0.1.0
appVersion: "1.0.0"
"@



### CONFIGMAP TEMPLATE CONTENT
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
### DEPLOYMENT TEMPLATE CONTENT
$deploymentTemplatePath = Join-Path -Path $rootFolderPath -ChildPath "application/main-app/templates/deployment.yaml"
$deploymentTemplateContent = @'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.serviceName }}
  namespace: {{ .Values.namespace }}
  labels:
    app.kubernetes.io/name: {{ .Values.serviceName }}
    app.kubernetes.io/instance: {{ .Values.serviceName }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Values.serviceName }}
      app.kubernetes.io/instance: {{ .Values.serviceName }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ .Values.serviceName }}
        app.kubernetes.io/instance: {{ .Values.serviceName }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Values.serviceName }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          {{- with .Values.image.command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.image.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          ports:
            - name: {{ .Values.service.name }}
              containerPort: {{ .Values.service.portContainer }}
              protocol: {{ .Values.service.protocol }}
          envFrom:
            - configMapRef:
                name: {{ .Values.serviceName }}-config
          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}

'@

$hpaTemplatePath = Join-Path -Path $rootFolderPath -ChildPath "application/main-app/templates/hpa.yaml"
### HPA TEMPLATE CONTENT
$hpaTemplateContent = @'
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .Values.serviceName }}
  namespace: {{ .Values.namespace }}
  labels:
    app.kubernetes.io/name: {{ .Values.serviceName }}
    app.kubernetes.io/instance: {{ .Values.serviceName }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Values.serviceName }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
'@

### INGRESS TEMPLATE CONTENT
$ingressTemplatePath = Join-Path -Path $rootFolderPath -ChildPath "application/main-app/templates/ingress.yaml"
$ingressTemplateContent = @'
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Values.serviceName }}
  namespace: {{ .Values.namespace }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ $.Values.serviceName }}
                port:
                  number: {{ (index $.Values.service.ports 0).port }}
          {{- end }}
    {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- toYaml .Values.ingress.tls | nindent 4 }}
  {{- end }}
{{- end }}
'@

### SERVICE TEMPLATE CONTENT
$serviceTemplatePath = Join-Path -Path $rootFolderPath -ChildPath "application/main-app/templates/service.yaml"
$serviceTemplateContent = @'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.serviceName }}
  namespace: {{ .Values.namespace }}
  labels:
    app.kubernetes.io/name: {{ .Values.serviceName }}
    app.kubernetes.io/instance: {{ .Values.serviceName }}
spec:
  type: {{ .Values.service.type }}
  ports:
    {{- range .Values.service.ports }}
    - name: {{ .name }}
      port: {{ .port }}
      targetPort: {{ .targetPort }}
      protocol: {{ .protocol }}
    {{- end }}
  selector:
    app.kubernetes.io/name: {{ .Values.serviceName }}
    app.kubernetes.io/instance: {{ .Values.serviceName }}

'@

Set-Content -Path $configMapTemplatePath -Value $configMapTemplateContent -Encoding UTF8
Set-Content -Path $deploymentTemplatePath -Value $deploymentTemplateContent -Encoding UTF8
Set-Content -Path $hpaTemplatePath -Value $hpaTemplateContent -Encoding UTF8
Set-Content -Path $ingressTemplatePath -Value $ingressTemplateContent -Encoding UTF8
Set-Content -Path $serviceTemplatePath -Value $serviceTemplateContent -Encoding UTF8
Set-Content -Path $chartTemplatePath -Value $chartTemplateContent -Encoding UTF8



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
