{{/*
Expand the name of the chart.
*/}}
{{- define "team-signaling.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Kombination aus Release-Name und Chart-Name.
Beispiel: helm install signaling team-signaling/ → "signaling-team-signaling"
*/}}
{{- define "team-signaling.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
