{{/*
Fully-qualified app name - just the chart name, since each service already
gets its own Helm release named after it (see helm/scalecart-umbrella/Chart.yaml).
*/}}
{{- define "common.fullname" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "common.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/part-of: scalecart
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: {{ .Chart.Name }}
tier: {{ .Values.tier | default "backend" }}
{{- end -}}

{{- define "common.selectorLabels" -}}
app: {{ .Chart.Name }}
{{- end -}}

{{/*
The same non-root / read-only-fs / drop-all-capabilities posture on every
container in the platform - defined once here instead of copy-pasted into
7 charts, so tightening this later is a one-line library-chart bump
instead of a 7-file edit. See docs/06-kubernetes-advanced.md.
*/}}
{{- define "common.securityContext" -}}
runAsNonRoot: true
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end -}}

{{/*
Full Deployment. Every service chart's templates/deployment.yaml is just:
  {{ include "common.deployment" . }}
with that service's values.yaml supplying the knobs (image, resources,
probes, initContainer, kafka-client label, etc.) - this is what keeps the
7 per-service charts from each re-deriving the same 80 lines of
boilerplate. See docs/09-helm-charts.md.
*/}}
{{- define "common.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Values.namespace }}
  labels: {{- include "common.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  revisionHistoryLimit: 5
  selector:
    matchLabels: {{- include "common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common.labels" . | nindent 8 }}
        {{- if .Values.kafkaClient }}
        scalecart.io/kafka-client: "true"
        {{- end }}
        {{- if .Values.version }}
        version: {{ .Values.version }}
        {{- end }}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: {{ .Values.port | quote }}
        prometheus.io/path: {{ .Values.metricsPath | default "/metrics" | quote }}
        checksum/config: {{ toYaml .Values.env | sha256sum }}
    spec:
      serviceAccountName: {{ include "common.fullname" . }}
      priorityClassName: {{ .Values.priorityClassName | default "scalecart-standard" }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds | default 30 }}
      {{- if .Values.topologySpread }}
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels: {{- include "common.selectorLabels" . | nindent 14 }}
      {{- end }}
      {{- if .Values.initContainer.enabled }}
      initContainers:
        - name: db-migrate
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command: {{ .Values.initContainer.command | toJson }}
          envFrom:
            - secretRef: { name: {{ include "common.fullname" . }}-secrets }
          securityContext: {{- include "common.securityContext" . | nindent 12 }}
      {{- end }}
      containers:
        - name: {{ include "common.fullname" . }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}
          ports:
            - containerPort: {{ .Values.port }}
          envFrom:
            - configMapRef: { name: {{ include "common.fullname" . }}-config }
            {{- if .Values.hasSecrets }}
            - secretRef: { name: {{ include "common.fullname" . }}-secrets }
            {{- end }}
          resources: {{- toYaml .Values.resources | nindent 12 }}
          {{- if .Values.startupProbe.enabled }}
          startupProbe:
            httpGet: { path: {{ .Values.startupProbe.path }}, port: {{ .Values.port }} }
            failureThreshold: {{ .Values.startupProbe.failureThreshold | default 30 }}
            periodSeconds: {{ .Values.startupProbe.periodSeconds | default 2 }}
          {{- end }}
          livenessProbe:
            httpGet: { path: {{ .Values.livenessProbe.path }}, port: {{ .Values.port }} }
            initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds | default 5 }}
            periodSeconds: {{ .Values.livenessProbe.periodSeconds | default 10 }}
          readinessProbe:
            httpGet: { path: {{ .Values.readinessProbe.path }}, port: {{ .Values.port }} }
            initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds | default 5 }}
            periodSeconds: {{ .Values.readinessProbe.periodSeconds | default 5 }}
            failureThreshold: {{ .Values.readinessProbe.failureThreshold | default 3 }}
          securityContext: {{- include "common.securityContext" . | nindent 12 }}
          {{- if or .Values.writableTmp .Values.extraVolumeMounts }}
          volumeMounts:
            {{- if .Values.writableTmp }}
            - { name: tmp, mountPath: /tmp }
            {{- end }}
            {{- with .Values.extraVolumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
      {{- if or .Values.writableTmp .Values.extraVolumes }}
      volumes:
        {{- if .Values.writableTmp }}
        - { name: tmp, emptyDir: {} }
        {{- end }}
        {{- with .Values.extraVolumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- end }}
{{- end -}}

{{- define "common.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Values.namespace }}
  labels: {{- include "common.labels" . | nindent 4 }}
spec:
  selector: {{- include "common.selectorLabels" . | nindent 4 }}
  ports:
    - port: {{ .Values.port }}
      targetPort: {{ .Values.port }}
      name: http
{{- end -}}

{{- define "common.hpa" -}}
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Values.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "common.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: { type: Utilization, averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage | default 70 }} }
{{- end }}
{{- end -}}

{{- define "common.pdb" -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Values.namespace }}
spec:
  minAvailable: {{ .Values.pdb.minAvailable }}
  selector:
    matchLabels: {{- include "common.selectorLabels" . | nindent 6 }}
{{- end -}}

{{- define "common.serviceAccount" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Values.namespace }}
  {{- if .Values.serviceAccount.irsaRoleArn }}
  annotations:
    eks.amazonaws.com/role-arn: {{ .Values.serviceAccount.irsaRoleArn }}
  {{- end }}
{{- end -}}

{{- define "common.configMap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "common.fullname" . }}-config
  namespace: {{ .Values.namespace }}
data: {{- toYaml .Values.env | nindent 2 }}
{{- end -}}
