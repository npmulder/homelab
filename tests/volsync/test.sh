#!/usr/bin/env bash
# End-to-end VolSync test: write -> snapshot -> destroy -> restore -> verify.
#
# Provisions a throwaway namespace with a source PVC, writes 50MiB of random
# data with a sha256 checksum, triggers a manual VolSync backup to the shared
# Kopia repo, deletes the source, restores into a new PVC via a manual
# ReplicationDestination, and verifies the checksum matches.
#
# Usage: bash tests/volsync/test.sh [--keep]
#   --keep   Skip namespace cleanup on success (useful for debugging).
set -euo pipefail

NAMESPACE="volsync-test"
APP="volsync-test"
SIZE_MB=50
TIMEOUT_BACKUP=600
TIMEOUT_RESTORE=600
TIMEOUT_JOB=300
KEEP=0

for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\033[0;36m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
ok()   { printf '\033[0;32m  ok\033[0m %s\n' "$*"; }
fail() { printf '\033[0;31m  FAIL\033[0m %s\n' "$*" >&2; }

cleanup() {
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log "test failed (rc=$rc) — leaving namespace ${NAMESPACE} for inspection"
    log "  kubectl -n ${NAMESPACE} get pvc,replicationsource,replicationdestination,job,pod"
    return
  fi
  if [[ $KEEP -eq 1 ]]; then
    log "test passed — --keep set, leaving namespace ${NAMESPACE}"
    return
  fi
  log "cleaning up namespace ${NAMESPACE}"
  kubectl delete namespace "${NAMESPACE}" --wait=false --ignore-not-found
}
trap cleanup EXIT

require() { command -v "$1" >/dev/null 2>&1 || { fail "missing dependency: $1"; exit 1; }; }
require kubectl
require yq

# ------------------------------------------------------------------ pre-flight
log "pre-flight"
kubectl get storageclass ceph-block >/dev/null || { fail "ceph-block StorageClass not found"; exit 1; }
kubectl get volumesnapshotclass csi-ceph-blockpool >/dev/null || { fail "csi-ceph-blockpool VolumeSnapshotClass not found"; exit 1; }
kubectl get clustersecretstore onepassword-connect >/dev/null || { fail "onepassword-connect ClusterSecretStore not found"; exit 1; }
kubectl get crd replicationsources.volsync.backube >/dev/null || { fail "VolSync CRDs not installed"; exit 1; }
ok "cluster looks healthy"

# ------------------------------------------------------------------ namespace
log "creating namespace ${NAMESPACE}"
kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 && {
  fail "namespace ${NAMESPACE} already exists — delete it first"
  exit 1
}
kubectl create namespace "${NAMESPACE}" >/dev/null
ok "namespace created"

# ------------------------------------------------------------------ kopia secret
log "creating ExternalSecret for Kopia credentials"
kubectl apply -n "${NAMESPACE}" -f - <<EOF >/dev/null
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: ${APP}-volsync
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword-connect
  target:
    name: ${APP}-volsync-secret
    template:
      data:
        KOPIA_PASSWORD: "{{ .KOPIA_PASSWORD }}"
        KOPIA_REPOSITORY: filesystem:///mnt/repository
  dataFrom:
    - extract:
        key: volsync-template
EOF

log "waiting for ${APP}-volsync-secret to materialize"
for i in $(seq 1 30); do
  if kubectl -n "${NAMESPACE}" get secret "${APP}-volsync-secret" >/dev/null 2>&1; then
    ok "secret ready"
    break
  fi
  sleep 2
  [[ $i -eq 30 ]] && { fail "ExternalSecret never produced ${APP}-volsync-secret"; exit 1; }
done

# ------------------------------------------------------------------ source PVC
log "creating source PVC"
kubectl apply -n "${NAMESPACE}" -f - <<EOF >/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${APP}-src
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ceph-block
EOF
kubectl -n "${NAMESPACE}" wait pvc/${APP}-src --for=jsonpath='{.status.phase}'=Bound --timeout=120s
ok "source PVC bound"

# ------------------------------------------------------------------ writer job
log "writing ${SIZE_MB}MiB of random data + sha256 checksum"
kubectl apply -n "${NAMESPACE}" -f - <<EOF >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${APP}-writer
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
        - name: writer
          image: busybox:1.37
          command:
            - sh
            - -ec
            - |
              dd if=/dev/urandom of=/data/random.bin bs=1M count=${SIZE_MB} status=none
              sha256sum /data/random.bin > /data/checksum.sha256
              echo "wrote payload:"
              ls -lh /data
              echo "checksum:"
              cat /data/checksum.sha256
              sync
          volumeMounts:
            - { name: data, mountPath: /data }
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ${APP}-src
EOF
kubectl -n "${NAMESPACE}" wait --for=condition=complete job/${APP}-writer --timeout=${TIMEOUT_JOB}s
EXPECTED_SHA=$(kubectl -n "${NAMESPACE}" logs job/${APP}-writer | awk '/random.bin$/ {print $1}' | tail -1)
[[ -n "$EXPECTED_SHA" ]] || { fail "could not capture expected checksum"; exit 1; }
ok "data written, expected sha256 = ${EXPECTED_SHA:0:16}…"

# ------------------------------------------------------------------ replicate
log "triggering manual VolSync backup"
kubectl apply -n "${NAMESPACE}" -f - <<EOF >/dev/null
apiVersion: volsync.backube/v1alpha1
kind: ReplicationSource
metadata:
  name: ${APP}
spec:
  sourcePVC: ${APP}-src
  trigger:
    manual: backup-once
  kopia:
    accessModes: [ReadWriteOnce]
    compression: zstd-fastest
    copyMethod: Snapshot
    moverSecurityContext:
      runAsUser: 1000
      runAsGroup: 1000
      fsGroup: 1000
    moverVolumes:
      - mountPath: repository
        volumeSource:
          nfs:
            path: /nfs/Kopia
            server: 10.20.0.15
    parallelism: 2
    repository: ${APP}-volsync-secret
    retain:
      hourly: 1
      daily: 1
    storageClassName: ceph-block
    volumeSnapshotClassName: csi-ceph-blockpool
EOF

log "waiting up to ${TIMEOUT_BACKUP}s for backup to complete"
for i in $(seq 1 ${TIMEOUT_BACKUP}); do
  LAST=$(kubectl -n "${NAMESPACE}" get replicationsource ${APP} -o jsonpath='{.status.lastManualSync}' 2>/dev/null || true)
  if [[ "$LAST" == "backup-once" ]]; then
    SYNC_TIME=$(kubectl -n "${NAMESPACE}" get replicationsource ${APP} -o jsonpath='{.status.lastSyncTime}')
    DURATION=$(kubectl -n "${NAMESPACE}" get replicationsource ${APP} -o jsonpath='{.status.lastSyncDuration}')
    ok "backup complete (lastSyncTime=${SYNC_TIME} duration=${DURATION})"
    break
  fi
  sleep 1
  if (( i % 30 == 0 )); then log "  …still waiting (${i}s); mover pod:"; kubectl -n "${NAMESPACE}" get pods -l app.kubernetes.io/created-by=volsync --no-headers 2>/dev/null || true; fi
  [[ $i -eq ${TIMEOUT_BACKUP} ]] && { fail "backup did not complete within ${TIMEOUT_BACKUP}s"; exit 1; }
done

# ------------------------------------------------------------------ destroy
log "destroying source PVC + writer job"
kubectl -n "${NAMESPACE}" delete replicationsource ${APP} --wait=true
kubectl -n "${NAMESPACE}" delete job ${APP}-writer --wait=true
kubectl -n "${NAMESPACE}" delete pvc ${APP}-src --wait=true
ok "source side wiped"

# ------------------------------------------------------------------ restore
log "creating ReplicationDestination to restore from Kopia"
kubectl apply -n "${NAMESPACE}" -f - <<EOF >/dev/null
apiVersion: volsync.backube/v1alpha1
kind: ReplicationDestination
metadata:
  name: ${APP}-dst
spec:
  trigger:
    manual: restore-once
  kopia:
    accessModes: [ReadWriteOnce]
    cacheAccessModes: [ReadWriteOnce]
    cacheCapacity: 1Gi
    cacheStorageClassName: openebs-hostpath
    capacity: 1Gi
    cleanupCachePVC: true
    cleanupTempPVC: true
    copyMethod: Snapshot
    moverSecurityContext:
      runAsUser: 1000
      runAsGroup: 1000
      fsGroup: 1000
    moverVolumes:
      - mountPath: repository
        volumeSource:
          nfs:
            path: /nfs/Kopia
            server: 10.20.0.15
    repository: ${APP}-volsync-secret
    sourceIdentity:
      sourceName: ${APP}
    storageClassName: ceph-block
    volumeSnapshotClassName: csi-ceph-blockpool
EOF

log "waiting up to ${TIMEOUT_RESTORE}s for restore snapshot to be produced"
for i in $(seq 1 ${TIMEOUT_RESTORE}); do
  LAST=$(kubectl -n "${NAMESPACE}" get replicationdestination ${APP}-dst -o jsonpath='{.status.lastManualSync}' 2>/dev/null || true)
  IMG=$(kubectl -n "${NAMESPACE}" get replicationdestination ${APP}-dst -o jsonpath='{.status.latestImage.name}' 2>/dev/null || true)
  if [[ "$LAST" == "restore-once" && -n "$IMG" ]]; then
    ok "restore snapshot ready (${IMG})"
    break
  fi
  sleep 1
  (( i % 30 == 0 )) && log "  …still waiting (${i}s)"
  [[ $i -eq ${TIMEOUT_RESTORE} ]] && { fail "restore did not produce a snapshot within ${TIMEOUT_RESTORE}s"; exit 1; }
done

# ------------------------------------------------------------------ restored PVC
log "creating restored PVC from ReplicationDestination"
kubectl apply -n "${NAMESPACE}" -f - <<EOF >/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${APP}-restored
spec:
  accessModes: [ReadWriteOnce]
  dataSourceRef:
    apiGroup: volsync.backube
    kind: ReplicationDestination
    name: ${APP}-dst
  resources:
    requests:
      storage: 1Gi
  storageClassName: ceph-block
EOF
kubectl -n "${NAMESPACE}" wait pvc/${APP}-restored --for=jsonpath='{.status.phase}'=Bound --timeout=120s
ok "restored PVC bound"

# ------------------------------------------------------------------ verify
log "running verifier job"
kubectl apply -n "${NAMESPACE}" -f - <<EOF >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${APP}-verifier
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
        - name: verifier
          image: busybox:1.37
          command:
            - sh
            - -ec
            - |
              echo "restored payload:"
              ls -lh /data
              echo "stored checksum:"
              cat /data/checksum.sha256
              echo "verifying..."
              cd /data && sha256sum -c checksum.sha256
          volumeMounts:
            - { name: data, mountPath: /data }
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ${APP}-restored
EOF

if ! kubectl -n "${NAMESPACE}" wait --for=condition=complete job/${APP}-verifier --timeout=${TIMEOUT_JOB}s 2>/dev/null; then
  fail "verifier job did not complete cleanly"
  kubectl -n "${NAMESPACE}" logs job/${APP}-verifier || true
  exit 1
fi

ACTUAL_SHA=$(kubectl -n "${NAMESPACE}" logs job/${APP}-verifier | awk '/random.bin$/ && $2 != "" {print $1}' | head -1)
log "verifier output:"
kubectl -n "${NAMESPACE}" logs job/${APP}-verifier | sed 's/^/    /'

if kubectl -n "${NAMESPACE}" logs job/${APP}-verifier | grep -q "random.bin: OK"; then
  ok "checksum matched — full backup/restore cycle verified"
else
  fail "checksum mismatch or verifier output unexpected"
  exit 1
fi

log "DONE — VolSync write→snapshot→destroy→restore→verify cycle passed"
