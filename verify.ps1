# 실습 환경 연결 상태 점검 (Windows PowerShell)
Write-Host "1) 호스트에서 클러스터 접속 확인"
kubectl --context docker-desktop cluster-info

Write-Host "`n2) Jenkins 컨테이너 기동 확인"
docker compose ps

Write-Host "`n3) Jenkins 웹 응답 확인"
try {
  $resp = Invoke-WebRequest -Uri "http://localhost:8080/login" -UseBasicParsing -TimeoutSec 5
  Write-Host "   HTTP $($resp.StatusCode)"
} catch {
  Write-Host "   ⚠️  Jenkins가 아직 기동 중일 수 있습니다. 1분 후 다시 시도해보세요: .\verify.ps1"
}

Write-Host "`n4) Jenkins 컨테이너 내부에서 K8s 클러스터 접속 확인 (가장 중요한 확인 단계)"
docker compose exec -T jenkins kubectl --context docker-desktop cluster-info
if ($LASTEXITCODE -ne 0) {
  Write-Host "`n   ❌ Jenkins 컨테이너 안에서 클러스터 접속에 실패했습니다." -ForegroundColor Red
  Write-Host "   문제 해결(TROUBLESHOOTING.md 3번 항목)을 참고하세요:"
  Write-Host "   docker compose exec jenkins cat /var/jenkins_home/.kube/config | Select-String server"
}
