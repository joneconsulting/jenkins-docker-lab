# 문제 해결 가이드

## 1) `docker compose up` 이 아예 실행되지 않음 / "Cannot connect to the Docker daemon"
Docker Desktop이 실행 중인지 확인하세요 (메뉴바/트레이의 고래 아이콘이 활성 상태여야 합니다).

## 2) `kubectl config get-contexts` 에 `docker-desktop` 이 없음
Docker Desktop 설정 > Kubernetes > Enable Kubernetes 를 켜고 "Apply & Restart" 하세요.
활성화 후 하단 상태가 "Kubernetes is running" 이 될 때까지 기다린 후 다시 확인합니다.

## 3) verify 스크립트에서 "Jenkins 컨테이너 안에서 클러스터 접속 실패"가 나올 때
가장 흔한 원인은 컨테이너 안에서 kubeconfig의 서버 주소(`kubernetes.docker.internal`)가
해석되지 않는 경우입니다. Docker Desktop은 보통 이 주소를 컨테이너 내부에서도 자동으로
연결해주지만, 일부 네트워크 환경(특히 회사 VPN/방화벽)에서는 막힐 수 있습니다.

확인:
```bash
docker compose exec jenkins cat /var/jenkins_home/.kube/config | grep server
```

해결 순서 (위에서부터 시도):
1. **VPN을 끄고** 다시 `bash verify.sh` / `.\verify.ps1` (사내 VPN이 사설 DNS를 강제하는 경우가 많습니다)
2. Docker Desktop을 재시작 후 다시 시도
3. 그래도 안 되면, 아래처럼 서버 주소를 `host.docker.internal`로 바꾼 별도 kubeconfig를 만들어 사용합니다.

   **macOS/Linux**
   ```bash
   mkdir -p .kubeconfig-container
   sed 's/kubernetes.docker.internal/host.docker.internal/' "$HOME/.kube/config" \
     > .kubeconfig-container/config
   ```
   그 다음 `.env` 파일의 `KUBE_CONFIG_PATH`를 `.kubeconfig-container/config` 의 절대경로로
   바꾸고 `docker compose down && docker compose up -d` 를 다시 실행하세요.

   **Windows (PowerShell)**
   ```powershell
   New-Item -ItemType Directory -Force -Path .kubeconfig-container | Out-Null
   (Get-Content "$env:USERPROFILE\.kube\config") `
     -replace '127.0.0.1', 'host.docker.internal' |
     Set-Content .kubeconfig-container\config

   "KUBE_CONFIG_PATH=$((Resolve-Path .kubeconfig-container\config).Path)" |
     Out-File -Encoding ascii -FilePath .env

   docker compose down
   docker compose up -d
   ```
4. 3번으로도 TLS 인증서 오류(`certificate is valid for ...`)가 나면, **로컬 실습에 한해서만**
   아래처럼 인증서 검증을 건너뛸 수 있습니다 (운영 환경에서는 절대 사용하지 마세요).

   **macOS/Linux**
   ```bash
   kubectl --context docker-desktop config set-cluster docker-desktop --insecure-skip-tls-verify=true --kubeconfig=.kubeconfig-container/config
   ```

   **Windows (PowerShell)**
   ```powershell
   kubectl --context docker-desktop config set-cluster docker-desktop --insecure-skip-tls-verify=true --kubeconfig=.kubeconfig-container\config
   docker compose restart jenkins
   ```

## 4) `docker build` 단계에서 권한 오류(permission denied on docker.sock)
이 실습 이미지는 root로 실행되도록 설계되어 있어 보통 발생하지 않습니다. 그래도 발생한다면
Docker Desktop을 재시작하고 `docker compose up -d --build --force-recreate` 로 다시 실행하세요.

## 4-1) Jenkins 파이프라인에서 "docker: not found" 오류
Jenkins 컨테이너 안에 docker CLI 바이너리 자체가 없다는 뜻입니다 (소켓 권한 문제와는 다른 오류입니다).

**즉시 확인:**
```bash
docker compose exec jenkins docker --version
```
이 명령이 실패한다면 이미지가 오래된 Dockerfile로 빌드되었거나, 빌드 중 설치가 실패한 것입니다.

**임시 조치 (지금 당장 수업을 진행해야 할 때):**
```bash
docker compose exec -u root jenkins bash -c "apt-get update && apt-get install -y docker.io"
docker compose exec jenkins docker --version
```
단, 이 방법은 컨테이너를 삭제(`docker compose down`)하면 다시 사라지는 임시 조치입니다.

**영구 해결 (권장):**
```bash
docker compose down
docker compose build --no-cache
docker compose up -d
bash verify.sh   # 또는 .\verify.ps1
```
최신 Dockerfile은 Debian 패키지(docker.io) 대신 Docker 공식 정적 바이너리를 직접 받아 설치하므로
배포판·버전에 따라 패키지가 없어서 발생하는 문제 자체가 없어집니다. `--no-cache`로 반드시
캐시 없이 새로 빌드해야 이전에 실패했던 레이어가 재사용되지 않습니다.

## 5) Jenkins 플러그인 설치 중 빌드가 느리거나 실패
사내망/VPN에서 플러그인 저장소(updates.jenkins.io)가 막혀 있을 수 있습니다. 개인 네트워크나
모바일 핫스팟에서 최초 빌드를 한 번 진행해보세요. 이후에는 `jenkins_home` 볼륨에 캐시되어
다시 빌드할 필요가 없습니다.

## 6) 포트 충돌 (8080, 8443 등 이미 사용 중)
`docker-compose.yml`의 `ports` 값을 예: `"18080:8080"` 처럼 왼쪽 숫자만 바꾸고,
이후 안내되는 URL의 포트 번호도 그에 맞게 바꿔서 접속하세요.

## 7) `kubectl rollout status` 가 타임아웃되며 실패
```bash
kubectl --context docker-desktop get pods -n sample-app-dev
kubectl --context docker-desktop describe pod <pod-이름> -n sample-app-dev
```
`ImagePullBackOff`가 보이면 `docker build` 단계가 먼저 성공했는지, 이미지 태그가
Jenkinsfile의 `${IMAGE}` 값과 일치하는지 확인하세요.

## 8) CRD 설치 중 "annotations: Too long: may not be more than 262144 bytes"
ArgoCD나 Argo Rollouts의 install.yaml을 일반 `kubectl apply`로 설치할 때 발생할 수
있습니다. CRD 정의가 커서, `kubectl apply`가 기록하려는 "이전 설정 전체" 주석이
Kubernetes의 256KB 제한을 넘기 때문입니다. `--server-side` 옵션을 추가해 재시도하세요.
```bash
kubectl --context docker-desktop apply --server-side -n argo-rollouts -f <install.yaml 주소>
```
이미 일반 apply로 일부가 생성된 상태라면 소유권 충돌이 날 수 있으니
`--server-side --force-conflicts` 로 실행하세요. (이 zip의 `EXERCISES.md`와
`argocd/install-argocd.sh`에는 이미 `--server-side`가 기본 반영되어 있습니다.)

## 9) 이미지 빌드 중 "지원하지 않는 아키텍처" 오류
Windows인데도 이 오류가 난다면, Docker Desktop/WSL2가 예상과 다른 아키텍처로 빌드를
시도하고 있는 것입니다 (드물지만 ARM 기반 Windows 기기이거나, buildx 기본 빌더 설정이
꼬여있는 경우 발생할 수 있습니다).

**즉시 우회:**
```powershell
$env:DOCKER_DEFAULT_PLATFORM = "linux/amd64"
docker compose build --no-cache
docker compose up -d
```

**원인 확인:**
```powershell
docker version --format "OS/Arch: {{.Server.Os}}/{{.Server.Arch}}"
docker run --rm jenkins/jenkins:lts dpkg --print-architecture
```
두 번째 명령 결과가 `amd64`나 `arm64`가 아닌 다른 값이라면 이 zip이 아니라 Docker
Desktop 설치 자체를 점검해야 합니다 (재설치 권장).
