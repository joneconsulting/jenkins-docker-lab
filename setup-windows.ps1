# Windows (PowerShell) 용 — Jenkins(Docker) + Docker Desktop Kubernetes 실습 환경 준비
$ErrorActionPreference = "Stop"

Write-Host "1) Docker 동작 확인"
try { docker info | Out-Null } catch { Write-Host "Docker가 실행 중이 아닙니다. Docker Desktop을 먼저 실행하세요." -ForegroundColor Red; exit 1 }
Write-Host "   OK"

Write-Host "2) Docker Desktop Kubernetes 컨텍스트 확인"
$ctx = kubectl config get-contexts docker-desktop 2>$null
if (-not $ctx) {
  Write-Host "'docker-desktop' 컨텍스트를 찾을 수 없습니다." -ForegroundColor Red
  Write-Host "Docker Desktop > Settings > Kubernetes > Enable Kubernetes 를 켜고 Apply & Restart 하세요."
  exit 1
}
Write-Host "   OK"

Write-Host "3) kubeconfig 경로를 .env 파일에 기록"
"KUBE_CONFIG_PATH=$env:USERPROFILE\.kube\config" | Out-File -Encoding ascii -FilePath .env
Get-Content .env

Write-Host "4) 네임스페이스 생성 (dev / staging / production)"
kubectl --context docker-desktop apply -f k8s/namespaces.yaml

Write-Host "5) Jenkins 컨테이너 빌드 및 기동 (최초 실행 시 수 분 소요될 수 있습니다)"
docker compose up -d --build

Write-Host ""
Write-Host "완료되면 http://localhost:8080 (admin / admin123!) 으로 접속하세요."
Write-Host "연결 상태를 확인하려면: .\verify.ps1"
