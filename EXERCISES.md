# 실습 Step-by-Step 가이드

이 문서 하나만 보고 처음부터 끝까지 실습을 따라할 수 있도록 작성했습니다.
Section 번호는 강의 교안(`Jenkins_vs_ArgoCD_비교실습_강의교안.docx`)의 Section 1~8과
동일합니다.

> **모든 명령은 별도 표시가 없는 한 `jenkins-docker-lab` 폴더 안에서, 호스트(맥/윈도우)
> 터미널에서 실행합니다.** 지금 그 폴더에 있는지 항상 먼저 확인하세요.
> ```bash
> ls docker-compose.yml
> ```
> 이 파일이 안 보이면 아직 잘못된 위치입니다 — `cd`로 `jenkins-docker-lab` 폴더로 이동하세요.

---

## 0. 시작하기 전에 (한 번만 하면 됨)

### 0-1. Docker Desktop 확인
1. Docker Desktop 실행
2. **Settings > Kubernetes > Enable Kubernetes** 체크 → Apply & Restart
3. 하단 고래 아이콘이 "Kubernetes is running" 상태가 될 때까지 대기 (수 분 소요)
4. 터미널에서 확인:
   ```bash
   kubectl config get-contexts
   ```
   목록에 `docker-desktop` 이 보이면 준비 완료.

### 0-2. 이 폴더를 본인 Git 저장소에 올리기
Jenkins와 ArgoCD 둘 다 **Git 저장소를 읽어서** 동작하기 때문에, 로컬 폴더 그대로는 안 되고
GitHub 같은 원격 저장소에 올려둔 상태여야 합니다. (예시 저장소:
`https://github.com/joneconsulting/jenkins-docker-lab`)

### 0-3. ArgoCD용 리포지토리 주소 치환
`argocd/sample-app-argo.yaml` 파일을 열어서 `<YOUR_REPO_URL>` 부분을 방금 push한
저장소 주소로 바꿔주세요. (예: `https://github.com/joneconsulting/jenkins-docker-lab`)
바꾼 뒤 다시 커밋·push 해야 합니다.
```bash
git add argocd/sample-app-argo.yaml
git commit -m "set repo url"
git push
```

---

## Section 2. 실습 환경 구성

### 2-1. Jenkins(Docker) + kubectl/docker CLI 이미지 빌드·기동
```bash
bash setup-mac.sh
```

```Windows Powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup-windows.ps1
```

내부적으로 다음을 자동으로 합니다: Docker 상태 확인 → `.env` 파일 생성 →
dev/staging/production 네임스페이스 생성 → 이미지 빌드 → 컨테이너 기동.
**최초 실행은 3~7분 정도 걸릴 수 있습니다.**

### 2-2. 정상 기동 확인
```bash
bash verify.sh
```
마지막 항목 "Jenkins 컨테이너 내부에서 K8s 클러스터 접속 확인"까지 정상(✅)이어야 다음
단계로 넘어갈 수 있습니다. 실패하면 `TROUBLESHOOTING.md` 를 먼저 확인하세요.

추가로 docker CLI가 실제로 있는지 한 번 더 확인:
```bash
docker compose exec jenkins docker --version
docker compose exec jenkins kubectl version --client
```
둘 다 버전 정보가 출력되어야 합니다.

### 2-3. Jenkins 접속
- http://localhost:8080
- 계정: `admin` / `admin123!`

### 2-4. ArgoCD 설치 (같은 클러스터에)
```bash
bash argocd/install-argocd.sh
```
출력 마지막에 나오는 **초기 admin 비밀번호를 꼭 복사해두세요.** (예: `Ab12CdEf34...`)
나중에 다시 확인하려면:
```bash
kubectl --context docker-desktop -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

(Windows Powershell)
kubectl --context docker-desktop -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath='{.data.password}' | base64 -d
```

### 2-5. ArgoCD UI 접속
새 터미널 탭을 열고:
```bash
kubectl --context docker-desktop port-forward svc/argocd-server -n argocd 8443:443
```
이 터미널은 **닫지 말고 그대로 열어두세요** (포트포워딩이 계속 떠 있어야 함).
브라우저에서 `https://localhost:8443` 접속 → 인증서 경고는 "고급 > 계속 진행" →
계정 `admin` / (2-4에서 복사한 비밀번호)로 로그인.

**체크포인트:** Jenkins와 ArgoCD 둘 다 로그인이 되면 Section 2 완료입니다.

---

## Section 3. Jenkins Push 배포 실습

### 3-1. Pipeline Job 생성 (최초 1회)
1. Jenkins 좌측 메뉴 **New Item** 클릭
2. 이름 입력 (예: `First-deploy`), **Pipeline** 선택 → OK
3. 아래로 스크롤 → **Pipeline** 섹션
4. **Definition**: `Pipeline script from SCM` 선택
5. **SCM**: `Git` 선택
6. **Repository URL**: 본인 저장소 주소 입력 (예: `https://github.com/joneconsulting/jenkins-docker-lab`)
7. **Branch Specifier**: `*/main`
8. **Script Path**: `Jenkinsfile` (기본값 그대로 두면 됨)
9. **저장(Save)**

### 3-2. 첫 배포 (dev)
1. Job 페이지에서 **Build with Parameters** 클릭
2. `TARGET_ENV` = `dev` 선택 → **Build**
3. 왼쪽 Build History에서 방금 빌드 번호 클릭 → **Console Output** 으로 진행 상황 확인
4. 아래 순서로 성공해야 합니다: `Checkout` → `Docker Build` → `Namespace 준비` → `Deploy` → `결과 확인 안내`
5. 성공하면 콘솔 마지막에 이렇게 나옵니다:
   ```
   ✅ 빌드 성공 — sample-app-dev
   ```

### 3-3. 배포 결과 확인
```bash
kubectl --context docker-desktop get pods -n sample-app-dev
```
Pod 2개가 `Running` 상태여야 합니다. 브라우저로 직접 보려면:
```bash
kubectl --context docker-desktop port-forward svc/sample-app 8081:80 -n sample-app-dev
```
브라우저에서 `http://localhost:8081` 접속.

### 3-4. staging / production 배포
3-2를 반복하되 `TARGET_ENV` 를 `staging`, `production` 으로 바꿔서 각각 한 번씩 더
Build with Parameters 실행. 아래로 세 네임스페이스 모두 배포됐는지 확인:
```bash
kubectl --context docker-desktop get deploy -A | grep sample-app
```

### 3-5. 코드 변경 → 재배포 체감
1. `app/index.html` 파일의 문구를 수정 (예: "버전: v2"로 변경)
2. 커밋 후 push:
   ```bash
   git add app/index.html
   git commit -m "update version text"
   git push
   ```
3. Jenkins Job에서 다시 `TARGET_ENV=dev` 로 Build
4. 3-3의 port-forward 명령을 다시 실행하고 브라우저 새로고침 → 수정한 문구 확인

**체크포인트:** 세 네임스페이스에 배포가 다 되고, 코드 수정 후 재배포까지 확인했다면
Section 3 완료입니다.

---

## Section 4. ArgoCD Pull 배포 실습

### 4-1. Application 생성
호스트 터미널에서 (Jenkins나 ArgoCD 컨테이너 안이 아니라 그냥 맥/윈도우 터미널):
```bash
kubectl --context docker-desktop apply -f argocd/sample-app-argo.yaml
```
(0-3 단계에서 `<YOUR_REPO_URL>` 을 이미 바꿔뒀어야 합니다. 안 바꿨다면 지금 바꾸고
push 후 이 명령을 다시 실행하세요.)

### 4-2. 상태 확인
```bash
kubectl --context docker-desktop get application -n argocd
```
`SYNC STATUS` 가 `Synced`, `HEALTH STATUS` 가 `Healthy` 로 바뀔 때까지 몇 초~1분 정도
기다립니다. (ArgoCD 기본 폴링 주기 때문에 약간의 지연이 있을 수 있습니다.)

더 빨리 확인하고 싶으면 ArgoCD UI(`https://localhost:8443`)에서 `argocd-demo-app`
카드를 클릭해 Sync 진행 상황을 시각적으로 볼 수 있습니다. 카드가 바로 안 보이면
UI 우측 상단 새로고침 버튼을 눌러보세요.

### 4-3. 배포 결과 확인
```bash
kubectl --context docker-desktop get pods -n argocd-demo-app
kubectl --context docker-desktop port-forward svc/argocd-demo-app 8082:80 -n argocd-demo-app
```
브라우저에서 `http://localhost:8082` 접속.

### 4-4. Self-Heal 첫 체감
```bash
kubectl --context docker-desktop scale deployment/argocd-demo-app --replicas=5 -n argocd-demo-app
kubectl --context docker-desktop get deploy argocd-demo-app -n argocd-demo-app --watch
```
처음엔 `5/5`로 바뀌지만, 몇 초 뒤 ArgoCD가 다시 `2/2`로 되돌립니다. `--watch` 는
`Ctrl + C` 로 종료하세요.

**체크포인트:** Application이 Synced/Healthy이고, replica를 강제로 바꿔도 자동으로
되돌아오는 것까지 확인했다면 Section 4 완료입니다.

---

## Section 5. 나란히 비교 실습 ★

Section 3(Jenkins)과 Section 4(ArgoCD)에서 배포한 두 앱이 **둘 다 떠 있어야** 진행됩니다.
자세한 절차는 `compare/README.md` 에 있으며, 핵심만 요약하면:

### 5-1. Drift 복구 비교
```bash
# Jenkins로 배포한 쪽 — 되돌아오지 않음
kubectl --context docker-desktop scale deployment/sample-app --replicas=5 -n sample-app-dev
kubectl --context docker-desktop get deploy sample-app -n sample-app-dev --watch
```
```bash
# ArgoCD로 배포한 쪽 — 자동으로 되돌아옴 (Section 4-4에서 이미 확인함)
```

### 5-2. 롤백 비교
- **Jenkins**: `git revert HEAD && git push` 후 Jenkins에서 다시 Build
- **ArgoCD**: `git revert` 로 `argocd/manifests/deployment.yaml` 변경을 되돌리고 push하면
  자동으로 재동기화됨 (추가 조작 불필요)

### 5-3. 배포 이력 확인
- **Jenkins**: Job 페이지의 Build History
- **ArgoCD**: `kubectl --context docker-desktop -n argocd describe application argocd-demo-app`
  하단 History, 또는 `git log argocd/manifests`

**체크포인트:** `compare/README.md` 맨 아래 표를 직접 채워보면서 두 방식의 차이를
정리해보세요.

---

## Section 6. Progressive Delivery 기초

### 6-1. Argo Rollouts 컨트롤러 설치
```bash
kubectl --context docker-desktop create namespace argo-rollouts
kubectl --context docker-desktop apply --server-side -n argo-rollouts -f \
  https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

(Windows Powershell)
kubectl --context docker-desktop apply --server-side -n argo-rollouts -f `
  https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml


```
> `--server-side`가 필요한 이유: Argo Rollouts의 CRD 정의가 커서 일반 `kubectl apply`로
> 설치하면 Kubernetes의 annotation 크기 제한(256KB)에 걸려 다음과 같은 에러가 날 수
> 있습니다 — `metadata.annotations: Too long: may not be more than 262144 bytes`.
> `--server-side`는 이 제한이 적용되는 annotation을 쓰지 않는 방식이라 이 문제를 피합니다.
> 만약 이미 일반 `apply`로 한 번 시도해서 일부 리소스가 생성된 상태라면
> `--server-side --force-conflicts` 로 실행하세요.

### 6-2. (선택) 시각화 플러그인 설치
`kubectl argo rollouts` 명령을 쓰려면 플러그인이 필요합니다. 설치 방법은
https://argoproj.github.io/argo-rollouts/installation/#kubectl-plugin-installation
참고 (실습 진행에 필수는 아니며, 없어도 `kubectl get rollout` 으로 상태 확인 가능).

### 6-3. Canary 데모 배포
```bash
kubectl --context docker-desktop apply -f rollouts/namespace.yaml
kubectl --context docker-desktop apply -f rollouts/rollout-canary.yaml
```

### 6-4. 진행 상황 관찰
플러그인이 있다면:
```bash
kubectl argo rollouts get rollout canary-demo -n rollout-demo --watch
```
플러그인이 없다면:
```bash
kubectl --context docker-desktop get rollout canary-demo -n rollout-demo --watch
```
`SetWeight`가 20 → (1분 대기) → 50 → (1분 대기) → 100 순서로 자동 진행되는 것을 관찰합니다.

### 6-5. 수동 승인으로 넘어가고 싶을 때
```bash
kubectl argo rollouts promote canary-demo -n rollout-demo
```
(플러그인 없으면 생략 가능 — 대기 시간이 지나면 자동으로 다음 단계로 넘어갑니다.)

**체크포인트:** 트래픽 비율이 20 → 50 → 100으로 단계적으로 올라가는 것을 확인했다면
Section 6 완료입니다.

**추가 명령어** 
```bash
$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
kubectl --context docker-desktop patch rollout canary-demo -n rollout-demo --type merge -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"kubectl.kubernetes.io/restartedAt\":\"$ts\"}}}}}"
```


---

## Section 7. 운영 기본기 비교

이 Section은 별도 실습 파일 없이 **개념 비교 위주**로 진행합니다 (알림 방식, RBAC 개념
비교). 강의 교안 Section 7 표를 참고하세요.

---

## Section 8. 종합 & Wrap-up

지금까지 만든 것을 정리하며 복습합니다. 추가로 실행할 명령은 없습니다.
바로 아래 "정리(초기화)"로 넘어가도 됩니다.

---

## 정리 (실습 종료 후 초기화)

```bash
# 포트포워딩 터미널들 Ctrl+C로 먼저 종료

docker compose down -v
kubectl --context docker-desktop delete ns \
  sample-app-dev sample-app-staging sample-app-production \
  argocd argocd-demo-app rollout-demo argo-rollouts \
  --ignore-not-found

(Windows Powershell)
kubectl --context docker-desktop delete ns `
  sample-app-dev sample-app-staging sample-app-production `
  argocd argocd-demo-app rollout-demo argo-rollouts `
  --ignore-not-found

```

---

## 막혔을 때

1. 지금 `jenkins-docker-lab` 폴더 안인지 먼저 확인 (`ls docker-compose.yml`)
2. `TROUBLESHOOTING.md` 에서 증상과 비슷한 항목 확인
3. 그래도 안 되면 실행한 명령과 에러 메시지 **전체**를 그대로 캡처해서 질문
