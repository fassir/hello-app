# Introdução
Este repositório serve de suporte para o repositorio hello-manifests. Neste repositório consta os arquivos necessários para a construção de uma pipeline CI/CD utilizando FastAPI, Docker, GitHub Actions e ArgoCD. 

# Requisitos
Os arquivos deste repositório são fixados de acordo com os arquivos dockerfile e requirements.txt.

# Arquivos necessários
Os arquivos necessários para a construção da pipeline CI/CD são:
- main.py
```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def root():
    # Mensagem inicial da aplicação
    return {"message": "Hello World"}
```

- Dockerfile
```Dockerfile
FROM python:3.9-slim-buster

# Definir o diretório de trabalho dentro do contêiner
WORKDIR /app

# Copiar o arquivo de requisitos (se houver) e instalar as dependências
# Para este exemplo simples, a única dependência é FastAPI e Uvicorn
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar o código da aplicação para o diretório de trabalho
COPY . .

# Expor a porta em que a aplicação FastAPI será executada
EXPOSE 8000

# Comando para iniciar a aplicação usando Uvicorn
# Uvicorn é um servidor ASGI para aplicações Python
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```
- requirements.txt
```bash
fastapi
uvicorn
```
- .github\workflows\main.yaml
```yaml
name: CI/CD Pipeline - Build, Push & Update ArgoCD Manifests
on:
  push:
    branches:
      - main
env:
  DOCKER_IMAGE_NAME: ${{ secrets.DOCKER_USERNAME }}/hello-app
  IMAGE_TAG: ${{ github.sha }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest 

    steps:
      - name: Checkout application code
        uses: actions/checkout@v4 

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3 

      - name: Log in to Docker Hub
        uses: docker/login-action@v3 
        with:
          username: ${{ secrets.DOCKER_USERNAME }} 
          password: ${{ secrets.DOCKER_PASSWORD }} 

      - name: Build and push Docker image
        uses: docker/build-push-action@v5 
        with:
          context: . 
          push: true 
          tags: |
            ${{ env.DOCKER_IMAGE_NAME }}:${{ env.IMAGE_TAG }}
            ${{ env.DOCKER_IMAGE_NAME }}:latest

      - name: Checkout ArgoCD manifests repository
        uses: actions/checkout@v4
        with:
          repository: seu-usuario-github/hello-manifests
          path: hello-manifests
          ssh-key: ${{ secrets.SSH_PRIVATE_KEY }}
```
Estas são as variáveis necessarias para criação do workflow dentro do github:

1.  **DOCKER_USERNAME** e **DOCKER_PASSWORD**:
    * Vá para o seu repositório `hello-app` no GitHub.
    * Clique em `Settings` (Configurações).
    * No menu lateral esquerdo, clique em `Secrets and variables` > `Actions`.
    ![image](images/image.png)
    * Clique em `New repository secret`.
    ![image](images/image-1.png)
    * Crie um segredo com o nome `DOCKER_USERNAME` e o valor do seu nome de usuário do Docker Hub.
    ![image](images/image-2.png)
    * Crie outro segredo com o nome `DOCKER_PASSWORD` e o valor da sua senha do Docker Hub.
    ![image](images/image-2.png)

2.  **SSH_PRIVATE_KEY**:
    * **Gerar um par de chaves SSH:** Abra seu terminal e execute:
        ```bash
        ssh-keygen -t rsa -b 4096 -C "github-actions-key" -f ~/.ssh/github_actions_rsa
        ```
        Quando perguntado por uma passphrase, apenas pressione Enter duas vezes
    * **Adicionar a chave privada como um segredo no repositório:**
        * Volte para o repositório `hello-app` no GitHub.
        * Vá para `Settings` > `Secrets and variables` > `Actions`.
        ![image](images/image.png)
        * Clique em `New repository secret`.
        ![image](images/image-1.png)
        * Crie um segredo com o nome `SSH_PRIVATE_KEY`.
        ![image](images/image-2.png)
        * Cole o **conteúdo completo** do arquivo `~/.ssh/github_actions_rsa` (começa com `-----BEGIN OPENSSH PRIVATE KEY-----` e termina com `-----END OPENSSH PRIVATE KEY-----`). Certifique-se de copiar tudo, incluindo as linhas de `BEGIN` e `END`.
