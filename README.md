<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&height=200&color=gradient&customColorList=0:1F9BD4,50:2E75B6,100:16265F&text=hello-app&fontColor=ffffff&fontSize=48&fontAlignY=35&desc=Pipeline%20CI%2FCD%20GitOps%20%7C%20FastAPI%20%2B%20Docker%20%2B%20GitHub%20Actions%20%2B%20ArgoCD&descAlignY=55&descSize=16&animation=twinkling" width="100%" />

[![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/features/actions)

[![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=flat-square&logo=argo&logoColor=white)](https://argoproj.github.io/cd/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![GitOps](https://img.shields.io/badge/padrão-GitOps-orange?style=flat-square)]()
[![Status](https://img.shields.io/badge/status-ativo-brightgreen?style=flat-square)]()
[![Licença](https://img.shields.io/badge/licença-MIT-lightgrey?style=flat-square)]()

</div>

---

## 📋 Sobre o Projeto

O **hello-app** demonstra um **pipeline CI/CD GitOps completo e funcional**, indo do código-fonte ao deploy em cluster Kubernetes de forma totalmente automatizada. É um projeto de referência para quem quer entender como as ferramentas modernas de DevOps se integram em um fluxo real de produção.

A aplicação em si é uma API simples com **FastAPI**, mas o valor real está na **arquitetura do pipeline**: cada push para a branch principal dispara o build automático da imagem Docker, publica no registry e aciona o **ArgoCD** para sincronizar o deploy no cluster Kubernetes.

---

<div align="center">

## 🛠️ Stack de Tecnologias

[![My Skills](https://skillicons.dev/icons?i=python,fastapi,docker,githubactions,kubernetes&theme=dark)](https://skillicons.dev)

</div>

| Camada | Tecnologia | Versão | Papel |
|---|---|---|---|
| **Aplicação** | Python + FastAPI | 3.11+ / 0.100+ | API REST containerizada |
| **Container** | Docker | 24+ | Empacotamento da aplicação |
| **CI** | GitHub Actions | — | Build + push da imagem |
| **Registry** | GitHub Container Registry | — | Armazenamento da imagem |
| **CD** | ArgoCD | 2.x | Sincronização GitOps |
| **Orquestração** | Kubernetes | 1.28+ | Execução dos containers |

---

## 📁 Estrutura do Repositório

```
hello-app/
│
├── .github/
│   └── workflows/
│       └── main.yml          # Pipeline CI/CD (GitHub Actions)
│
├── app/
│   ├── main.py               # Entrypoint FastAPI
│   └── requirements.txt      # Dependências Python
│
├── Dockerfile                # Imagem Docker da aplicação
└── README.md
```

---

## 🔄 Pipeline CI/CD — Fluxo Completo

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PIPELINE CI/CD END-TO-END                            │
│                                                                         │
│  1. DEV                                                                 │
│  ┌──────────────┐                                                       │
│  │  git push    │                                                       │
│  │  (main)      │                                                       │
│  └──────┬───────┘                                                       │
│         │ trigger                                                       │
│         ▼                                                               │
│  2. CI — GitHub Actions (.github/workflows/main.yml)                    │
│  ┌───────────────────────────────────────────┐                         │
│  │  checkout → build Docker → push GHCR      │                         │
│  │  → atualiza tag em hello-manifests        │                         │
│  └───────────────────┬───────────────────────┘                         │
│                      │                                                  │
│                      ▼                                                  │
│  3. CD — ArgoCD monitora hello-manifests                                │
│  ┌───────────────────────────────────────────┐                         │
│  │  detecta mudança → sincroniza manifests   │                         │
│  │  → aplica no cluster Kubernetes           │                         │
│  └───────────────────┬───────────────────────┘                         │
│                      │                                                  │
│                      ▼                                                  │
│  4. Kubernetes executa o deploy                                         │
│  ┌───────────────────────────────────────────┐                         │
│  │  pull nova imagem → rolling update        │                         │
│  │  → pods saudáveis ✓                       │                         │
│  └───────────────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Etapas do Pipeline em Detalhes

<details>
<summary>🐍 <strong>Etapa 1 — Aplicação FastAPI</strong></summary>

<br>

A aplicação é uma API HTTP simples construída com FastAPI:

```python
# app/main.py
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello from hello-app!", "status": "running"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}
```

**Para executar localmente (sem Docker):**

```bash
pip install -r app/requirements.txt
uvicorn app.main:app --reload --port 8000
```

Acesse: `http://localhost:8000` e `http://localhost:8000/docs`

</details>

<details>
<summary>🐳 <strong>Etapa 2 — Dockerfile (Multi-stage)</strong></summary>

<br>

```dockerfile
# Dockerfile
FROM python:3.11-slim AS base

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Build e execução manual:**

```bash
# Build da imagem
docker build -t hello-app:local .

# Executar container
docker run -p 8000:8000 hello-app:local

# Testar
curl http://localhost:8000
```

</details>

<details>
<summary>⚡ <strong>Etapa 3 — GitHub Actions (main.yml)</strong></summary>

<br>

```yaml
# .github/workflows/main.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main]

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout código
        uses: actions/checkout@v3

      - name: Login no GHCR
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build e Push da imagem
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: |
            ghcr.io/fassir/hello-app:latest
            ghcr.io/fassir/hello-app:${{ github.sha }}

      - name: Atualizar manifests (hello-manifests)
        run: |
          git clone https://x-access-token:${{ secrets.MANIFEST_TOKEN }}@github.com/fassir/hello-manifests.git
          cd hello-manifests
          sed -i "s|image: .*|image: ghcr.io/fassir/hello-app:${{ github.sha }}|" hello-app/deployment.yaml
          git config user.email "ci@github.com"
          git config user.name "GitHub Actions"
          git add .
          git commit -m "ci: atualiza imagem para ${{ github.sha }}"
          git push
```

</details>

<details>
<summary>🔄 <strong>Etapa 4 — ArgoCD + Kubernetes</strong></summary>

<br>

Com o repositório `hello-manifests` atualizado, o ArgoCD detecta a mudança e executa a sincronização:

```bash
# Verificar o status da sincronização no ArgoCD
argocd app get hello-app

# Forçar sincronização manual (se necessário)
argocd app sync hello-app

# Verificar pods após deploy
kubectl get pods -l app=hello-app

# Acompanhar rolling update
kubectl rollout status deployment/hello-app
```

</details>

---

## 🧪 Testando com Port-Forward

```bash
# Após o deploy, expor o serviço localmente
kubectl port-forward svc/hello-app-service 8080:80

# Em outro terminal, testar os endpoints
curl http://localhost:8080/
# {"message":"Hello from hello-app!","status":"running"}

curl http://localhost:8080/health
# {"status":"healthy"}

# Acessar documentação interativa da API
open http://localhost:8080/docs
```

---

## 🔗 Repositório de Manifests

| Repositório | Descrição |
|---|---|
| [fassir/hello-manifests](https://github.com/fassir/hello-manifests) | Manifests Kubernetes para deploy via ArgoCD |

---

## 👤 Autor

<div align="center">

| | |
|---|---|
| **Nome** | Fabio Piassi |
| **LinkedIn** | [linkedin.com/in/fabio-piassi](https://linkedin.com/in/fabio-piassi) |
| **GitHub** | [github.com/fassir](https://github.com/fassir) |

</div>

---

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&section=footer&height=120&color=gradient&customColorList=0:16265F,50:2E75B6,100:1F9BD4" width="100%" />

*Pipeline CI/CD GitOps end-to-end com FastAPI, Docker, GitHub Actions e ArgoCD*

</div>
