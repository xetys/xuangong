{{/*
Expand the name of the chart.
*/}}
{{- define "xuangong-backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "xuangong-backend.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "xuangong-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "xuangong-backend.labels" -}}
helm.sh/chart: {{ include "xuangong-backend.chart" . }}
{{ include "xuangong-backend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "xuangong-backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "xuangong-backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "xuangong-backend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "xuangong-backend.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database URL
*/}}
{{- define "xuangong-backend.databaseURL" -}}
{{- $host := .Values.config.database.host -}}
{{- $port := .Values.config.database.port -}}
{{- $name := .Values.config.database.name -}}
{{- $user := .Values.config.database.user -}}
{{- $sslmode := .Values.config.database.sslMode -}}
{{- $password := .Values.secrets.databasePassword -}}
{{- printf "postgres://%s:%s@%s:%d/%s?sslmode=%s" $user $password $host (int $port) $name $sslmode }}
{{- end }}
