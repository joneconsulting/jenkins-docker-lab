# ArgoCD를 (Jenkins가 배포 중인 것과) 동일한 Docker Desktop Kubernetes 클러스터에 설치합니다.
#
# 왜 K8s에 설치하나요?
#   ArgoCD는 Kubernetes API를 직접 감시·제어하는 컨트롤러입니다.
#   "Docker 컨테이너로만" 띄우는 방식은 존재하지 않습니다 — 반드시 어떤 Kubernetes 클러스터를
#   대상으로 동작해야 하므로, 이미 켜져 있는 Docker Desktop Kubernetes를 그대로 쓰는 것이
#   별도 클러스터를 새로 준비하는 것보다 훨씬 간단하고 실습하기 쉽습니다.

$ErrorActionPreference = "Stop"

function Assert-Success {
  param([string]$Step)
  if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ '$Step' 단계에서 실패했습니다 (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit 1
  }
}

Write-Host "1) argocd 네임스페이스 생성"
kubectl --context docker-desktop create namespace argocd --dry-run=client -o yaml | `
  kubectl --context docker-desktop apply -f -
Assert-Success "네임스페이스 생성"

Write-Host "2) ArgoCD 설치"
kubectl --context docker-desktop apply --server-side -n argocd -f `
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
Assert-Success "ArgoCD 설치"
Write-Host "   (이미 일반 apply로 일부가 설치된 상태라 충돌 오류가 나면 아래로 다시 실행하세요)"
Write-Host "   kubectl --context docker-desktop apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

Write-Host "3) 컴포넌트 기동 대기 (수 분 소요될 수 있습니다)"
kubectl --context docker-desktop -n argocd rollout status deploy/argocd-server --timeout=180s
Assert-Success "컴포넌트 기동 대기"

Write-Host "4) 초기 admin 비밀번호"
$encoded = kubectl --context docker-desktop -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'
Assert-Success "초기 비밀번호 조회"
$password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encoded))
Write-Host $password -ForegroundColor Yellow
Write-Host ""

Write-Host "5) UI 접속: 아래 명령 실행 후 https://localhost:8443 접속 (인증서 경고는 '고급 > 계속 진행')"
Write-Host "   kubectl --context docker-desktop port-forward svc/argocd-server -n argocd 8443:443"
Write-Host "   계정: admin / (위에서 출력된 비밀번호)"
