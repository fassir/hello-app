
# 1. Objetivo
Este projeto visa demonstrar a implementação em outro [repositório](https://github.com/fassir/hello-manifests) de uma pipeline de CI/CD utilizando FastAPI, Docker, GitHub Actions e ArgoCD. A seguir, você encontrará um guia passo a passo para configurar e executar essa pipeline.
# 2. Metodologia
Para implementar a pipeline de CI/CD, seguiremos os seguintes passos:
1. [Criando a aplicação FastAPI](#1-criando-a-aplicação-fastapi)

    1.1 [Arquivos necessários](#11-arquivos-necessários)

    1.2 [Variáveis de ambiente](#12-variáveis-de-ambiente)

    1.3 [Executando ações diretório do projeto](#13-executando-ações-diretório-do-projeto)

2. [Repositório Git com os manifests do ArgoCD](#2-repositório-git-com-os-manifests-do-argocd)

    2.1 [Criar os manifestos do Kubernetes de deployment e service para o Hello App](#21-criar-os-manifestos-do-kubernetes-de-deployment-e-service-para-o-hello-App)

    2.2 [Criar o App no ArgoCD](#22-criar-o-app-no-argocd)

    2.3 [Na interface do ArgoCD criar o vínculo com o repositório de manifestos](#23-na-interface-do-ArgoCD-criar-o-vínculo-com-o-repositório-de-manifestos)

    2.4 [Criar o app no ArgoCD](#24-criar-o-app-no-argocd)

3. [Acessar e testar a aplicação localmente](#3-acessar-e-testar-a-aplicação-localmente)

    3.1 [Criando o port-forward](#31-criando-o-port-forward)

    3.2 [Alterando o repositório](#32-alterando-o-repositório)

    3.3 [Monitore o GitHub Actions](#33-monitore-o-github-actions)

    3.4 [Monitore o ArgoCD](#34-monitore-o-argocd)

    3.5 [Verifique a aplicação atualizada](#35-verifique-a-aplicação-atualizada)

Uma vez apresentado os passos seguiremos com a implementação.
# 1.  Criando a aplicação FastAPI
Esta etapa envolve a criação da sua aplicação FastAPI e a configuração do Docker de execução.

Criar um repositório Git para o projeto com os arquivos:

 ## 1.1.  Arquivos necessários
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
name: CI/CD Pipeline - Build, Push & Update ArgoCD Manifests (Two Repositories)

on:
  push:
    branches:
      - main

env:
  DOCKER_USERNAME_SECRET: ${{ secrets.DOCKER_USERNAME_VALUE }}
  DOCKER_IMAGE_REPO_SECRET: ${{ secrets.DOCKER_IMAGE_REPO_NAME }}

  GITHUB_OWNER_SECRET: ${{ secrets.GITHUB_OWNER_USERNAME }}
  MANIFESTS_REPO_NAME_SECRET: ${{ secrets.GITHUB_MANIFESTS_REPO_NAME }}

  IMAGE_TAG: ${{ github.sha }}
  
  MANIFESTS_PATH_IN_REPO: hello-app
  LOCAL_MANIFESTS_CLONE_PATH: manifests-repo-clone 

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: write      
      pull-requests: write 

    steps:
    - name: Checkout application code (hello-app)
      uses: actions/checkout@v4
      with:
        token: ${{ secrets.GITHUB_TOKEN }}

    - name: Log in to Docker Hub
      uses: docker/login-action@v3
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}

    - name: Build and push Docker image
      id: docker_build
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: |
          ${{ env.DOCKER_USERNAME_SECRET }}/${{ env.DOCKER_IMAGE_REPO_SECRET }}:${{ env.IMAGE_TAG }}
          ${{ env.DOCKER_USERNAME_SECRET }}/${{ env.DOCKER_IMAGE_REPO_SECRET }}:latest
        outputs: |
          type=image,value=${{ env.DOCKER_USERNAME_SECRET }}/${{ env.DOCKER_IMAGE_REPO_SECRET }}:${{ env.IMAGE_TAG }}
          type=image,value=${{ env.DOCKER_USERNAME_SECRET }}/${{ env.DOCKER_IMAGE_REPO_SECRET }}:latest
          type=image,value=${{ steps.docker_build.outputs.digest }}

    - name: Checkout manifests repository (hello-manifests)
      uses: actions/checkout@v4
      with:
        repository: ${{ env.GITHUB_OWNER_SECRET }}/${{ env.MANIFESTS_REPO_NAME_SECRET }}
        path: ${{ env.LOCAL_MANIFESTS_CLONE_PATH }} 
        ssh-key: ${{ secrets.SSH_PRIVATE_KEY }} 

    - name: Update image tag in deployment.yaml
      id: update_manifest
      run: |
        cd ${{ env.LOCAL_MANIFESTS_CLONE_PATH }}/${{ env.MANIFESTS_PATH_IN_REPO }}
        
        sed -i "s|image: ${{ env.DOCKER_USERNAME_SECRET }}/${{ env.DOCKER_IMAGE_REPO_SECRET }}:.*|image: ${{ env.DOCKER_USERNAME_SECRET }}/${{ env.DOCKER_IMAGE_REPO_SECRET }}:${{ env.IMAGE_TAG }}|g" deployment.yaml
        
        echo "Conteúdo de deployment.yaml atualizado:"
        cat deployment.yaml 
        
        if ! git diff --quiet --exit-code deployment.yaml; then
          echo "changes_detected=true" >> $GITHUB_OUTPUT
          echo "Changes detected in deployment.yaml. Ready to create Pull Request."
        else
          echo "changes_detected=false" >> $GITHUB_OUTPUT
          echo "No changes detected in deployment.yaml. Skipping Pull Request."
        fi
      working-directory: ${{ github.workspace }} 

    - name: Create Pull Request
      if: steps.update_manifest.outputs.changes_detected == 'true'
      uses: peter-evans/create-pull-request@v5
      with:
        token: ${{ secrets.GH_PAT_FOR_MANIFESTS }} 
        
        commit-message: "feat(app): Update hello-app image to ${{ env.IMAGE_TAG }}"
        title: "Atualização da Imagem hello-app para novo SHA"
        body: |
          Este Pull Request atualiza a tag da imagem `hello-app` para o novo SHA: `${{ env.IMAGE_TAG }}` no `deployment.yaml`.
          Disparado por push no repositório da aplicação.
        branch: "update-image-tag-${{ github.sha }}"
        base: "main"
        delete-branch: true
        repository: ${{ env.GITHUB_OWNER_SECRET }}/${{ env.MANIFESTS_REPO_NAME_SECRET }} 
        path: ${{ env.LOCAL_MANIFESTS_CLONE_PATH }}
```
Estas são as variáveis necessarias para criação do workflow dentro do github:

  ## 1.2  Variáveis de ambiente
- **DOCKER_USERNAME_VALUE**, **DOCKER_PASSWORD**, **DOCKER_IMAGE_REPO_NAME** e **GITHUB_MANIFESTS_REPO_NAME**:

    * Vá para o seu repositório `hello-app` no GitHub.
    
    * Clique em `Settings` (Configurações).
    
    * No menu lateral esquerdo, clique em `Secrets and variables` > `Actions`.
    
    ![image](images/image.png)
    
    * Clique em `New repository secret`.
    
    ![image](images/image-1.png)
    
    * Crie um segredo com o nome `DOCKER_USERNAME_VALUE` e Valor: seu nome de usuário real do Docker Hub.
    
    ![image](images/image-2.png)
    
    * Crie outro segredo com o nome `DOCKER_IMAGE_REPO_NAME` e o nome do seu repositório da imagem Docker.
    
    ![image](images/image-2.png)
    
    * Crie outro segredo com o nome `GITHUB_OWNER_USERNAME` e o nome de usuário/organização real do GitHub que é dono dos repositórios.
    
    ![image](images/image-2.png)
    
    * Crie outro segredo com o nome `GITHUB_MANIFESTS_REPO_NAME` e o nome de usuário/organização real do GitHub que é dono dos repositórios.
    
    ![image](images/image-2.png)
    
-  **SSH_PRIVATE_KEY**:
    * **Gerar um par de chaves SSH:** 
    * Abra seu terminal e *execute:
        ```bash
        ssh-keygen -t rsa -b 4096 -C "github-actions-key" -f ~/.ssh/github_actions_rsa
        ```
        Quando perguntado por uma passphrase, apenas pressione Enter duas vezes
    * **Adicionar a chave privada como um segredo no repositório:**
        * Volte para o repositório **hello-app** no GitHub.
        * Vá para `Settings` > `Secrets and variables` > `Actions`.
        ![image](images/image.png)
        * Clique em `New repository secret`.
        ![image](images/image-1.png)
        * Crie um segredo com o nome `SSH_PRIVATE_KEY`.
        ![image](images/image-2.png)
        * Cole o **conteúdo completo** do arquivo `~/.ssh/github_actions_rsa` (começa com `-----BEGIN OPENSSH PRIVATE KEY-----` e termina com `-----END OPENSSH PRIVATE KEY-----`). Certifique-se de copiar tudo, incluindo as linhas de `BEGIN` e `END`.

    * **Chave pública para repositório hello-app**
        
      * Adicionar a chave pública ao repositório **hello-manifests**:
        
      * Vá para hello-manifests > Settings > Deploy keys.
        
        ![image](images/image.png)
        ![image](images/image-1.png)
      * Clique em Add deploy key.
        ![image](images/image-2.png)
        
        **Title**: github-actions-for-hello-app (ou um nome descritivo)
        
        **Key**: Cole o conteúdo do arquivo público: cat ~/.ssh/github_actions_manifests_rsa_key.pub
        
      * Marque a opção "Allow write access". Isso é crucial para que o GitHub Actions possa fazer commits/PRs nesse repositório.
      * Outra coisa que pode estar desconfigurada é a opção 'workflow permissions. Ela está localizada no repositório em 'setings > Actions > General. 

      ![alt text](images/image-23.png)
      
      * Marque em 'read and write permissions' para que as ações possam modificar o repositório.
      
      ![alt text](images/image-10.png)

  * **Public Access Token**
      
      * Caso a aplicação esteja com erros de receber a solicitação, essa chave permitirá que a aplicação tenha acesso, mesmo que o repositório seja privado. Para criá-lo vá nas configurações da conta do github
      
      ![alt text](images/image-13.png)
      
      * Após entrar neste menu, vá em Personal access tokens > Tokens (classic)
      
      * selecione Generate new token > Generate new tokens (classic)
      
       ![alt text](images/image-14.png)
      
      * Defina o tempo e o nome que o token terá para lembrar de seu uso. Selecione as permissões para o repositório (só é necessario repo:status e repo_deployments mas como a chave não será passada para terceiros marcar a opção repo não terá grande vazamento de prioridades)
      
      ![alt text](images/image-15.png)
      
      * Ao final da página terá o botão "Generate token" que irá gerá-lo. Lembre-se de armazená-lo em lugar seguro pois não é possível revê-lo novamente.
      
      * Uma vez em posse dele, ele será usado como senha para seu repositório hello-manifests no argo (passo [23](#23-na-interface-do-argocd-criar-o-vinculo-com-o-repositorio-de-manifestos))

## 1.3 Executando ações diretório do projeto

- Para criar o repositório, usamos os seguintes comando:

```bash
git init
git add main.py
git commit -m "Initial commit: Add FastAPI app"
git branch -M main
git remote add origin <URL_DO_SEU_REPOSITORIO_HELLO_APP> # Ex: https://github.com/seu-usuario/hello-app.git
git push -u origin main

```

- Criar um Dockerfile para executar esse aplicativo
No mesmo diretório do seu projeto hello-app, crie um arquivo chamado Dockerfile com o seguinte conteúdo:

- Adicione e commite esses novos arquivos ao seu repositório hello-app:

```bash
git add Dockerfile requirements.txt
git commit -m "Add Dockerfile and requirements"
git push origin main
```
## 1.4 Criar um repositório Git para os manifestos do ArgoCD (exemplo: hello-manifests)
- Crie um novo e vazio repositório no GitHub (ou em sua plataforma Git preferida) chamado hello-manifests. Este repositório conterá os arquivos de configuração do Kubernetes (manifestos) que o ArgoCD usará para implantar sua aplicação.

  - **Este repositório pode ser privado ou público. Para maior segurança e para demonstrar a configuração de chaves SSH no GitHub Actions, é comum que este repositório seja privado. Se você optar por torná-lo público, o processo de configuração da chave SSH ainda é válido e robusto para o acesso de escrita.**

## 1.5 Commitar e Enviar os Arquivos Iniciais
- No seu terminal (Git Bash, PowerShell ou CMD) dentro do diretório hello-app:

```bash
git add .
git commit -m "Initial commit: Add FastAPI app, Dockerfile, and requirements"
git push origin main
```

- Para que o GitHub Actions possa fazer login no Docker Hub e fazer um Pull Request no repositório de manifestos, você precisará configurar alguns [segredos](#12-variáveis-de-ambiente) no seu repositório `hello-app`.

- Com esses segredos configurados e o arquivo de workflow no lugar, seu pipeline de CI/CD está pronto para ser acionado em cada push para a branch `main` do seu repositório `hello-app`.

# 2. Repositório Git com os manifests do ArgoCD
- Nesta etapa, você criará os arquivos de manifesto do Kubernetes (deployment.yaml e service.yaml) que o ArgoCD usará para implantar sua aplicação. Estes arquivos serão armazenados no repositório hello-manifests que você criou anteriormente.

## 2.1 Criar os manifestos do Kubernetes de deployment e service para o Hello App 
- Clone o repositório hello-manifests para sua máquina local:
```bash
git clone git@github.com:seu-usuario-github/hello-manifests.git 
cd hello-manifests
```

- Dentro do diretório hello-manifests, crie uma pasta para sua aplicação, por exemplo, hello-app/.
```bash
mkdir hello-app
cd hello-app
```
- Crie o arquivo deployment.yaml dentro da pasta hello-app com o seguinte conteúdo. Lembre-se de substituir seu-usuario-docker pelo seu nome de usuário do Docker Hub.

### hello-app/deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-app-deployment
  labels:
    app: hello-app
spec:
  replicas: 1 # Número de réplicas do pod
  selector:
    matchLabels:
      app: hello-app
  template:
    metadata:
      labels:
        app: hello-app
    spec:
      containers:
      - name: hello-app
        
        # A tag ':latest' é um fallback, mas o CI/CD usará o SHA do commit
        image: seu-usuario-docker/hello-app:latest 
        ports:
        - containerPort: 8000 # Porta que sua aplicação FastAPI expõe
```
- Em seguida, crie o arquivo service.yaml no mesmo diretório hello-app para expor sua aplicação:

### hello-app/service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-app-service
  labels:
    app: hello-app
spec:
  selector:
    app: hello-app
  ports:
    - protocol: TCP
      port: 80 
      targetPort: 8000 # ou outra porta que não esteja em uso. Não use as mesmas portas que outras aplicações estejam usando para não entrarem em conflito 
  type: LoadBalancer
```
- Adicione e commite esses manifestos ao seu repositório hello-manifests:

```bash
git add .
git commit -m "Add initial Kubernetes manifests for hello-app"
git push origin main
```

- Este repositório agora está pronto para ser monitorado pelo ArgoCD.

## 2.2 Criar o App no ArgoCD
- É uma boa prática isolar o ArgoCD em seu próprio namespace.

```Bash
kubectl create namespace argocd
```

- Aplique os manifestos de instalação do ArgoCD diretamente no seu cluster.

```Bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

- Aguarde alguns minutos para que os pods do ArgoCD sejam iniciados. Você pode monitorar o progresso:

```Bash
kubectl get pods -n argocd
```
- Você deve ver vários pods, como argocd-server, argocd-repo-server, argocd-application-controller, etc., todos com status Running. Para interagir com o ArgoCD, você precisará acessar sua interface web. O serviço argocd-server é um ClusterIP por padrão, o que significa que ele não é acessível externamente sem um port-forward ou um Ingress.

- Usando Port-Forward, encaminhando o tráfego da porta 8080 da sua máquina local para a porta 443 do serviço argocd-server dentro do cluster.
```Bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

- Abrir seu navegador e vá para https://localhost:8080. Você pode receber um aviso de certificado inválido, pois é um certificado autoassinado. Você pode prosseguir com segurança.
![alt text](images/image-19.png)
- Fazer Login no ArgoCD CLI. A primeira vez que você acessa a interface web, ou se quiser usar a CLI do ArgoCD, precisará de uma senha. A senha inicial para o usuário admin é o nome do pod argocd-server.

- Obtenha o nome do pod argocd-server:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
**Para o Windows, use o git bash para executar esse comando**

- Copie a saída deste comando. Esta é a sua senha inicial.

* Username: admin

* Password: Cole o nome do pod argocd-server que você obteve no passo anterior.

- A criação do aplicativo no ArgoCD pode ser feita via interface web (UI) ou via argocd CLI.

## 2.3 Na interface do ArgoCD criar o vínculo com o repositório de manifestos
- Acesse a UI do ArgoCD: Abra seu navegador e navegue até a URL do seu painel do ArgoCD (geralmente https://argocd.example.com ou http://localhost:8080 se estiver usando port-forward).

- Faça login: Utilize suas credenciais de administrador do ArgoCD.

- Adicione novo repositório no menu lateral esquerdo, clique em Settings (Configurações).

- Em Repositories, clique em + New Repo e preencha os detalhes do seu repositório hello-manifests:
![alt text](images/image-21.png)
![alt text](images/image-22.png)
  - Repository URL: https://github.com/seu-usuario-github/hello-manifests.git (substitua seu-usuario-github).

  - Name: hello-manifests (ou um nome de sua preferência).

  - Authentication: Se o repositório for público, não precisa de credenciais. Se for privado, você pode usar um token de acesso pessoal do GitHub ou SSH. Para SSH, use a mesma chave privada que você configurou no GitHub Actions (mas certifique-se de que ela não tem passphrase). Caso tenha problemas posteriores, use a seu usuário github e senha o [PAT](#12-variáveis-de-ambiente) 

- Clique em CONNECT.
![alt text](images/image-3.png)
- O ArgoCD agora tem acesso ao seu repositório de manifestos e pode monitorá-lo.

## 2.4 Criar o app no ArgoCD
- Crie uma nova aplicação no menu lateral esquerdo, clique em Applications.

- Clique no botão + NEW APP e preencha os detalhes da nova aplicação:
![alt text](images/image-4.png)
  - Application Name: hello-app

  - Project: default (ou o projeto que você preferir)

    - SYNC POLICY: Selecione Automatic e marque PRUNE e SELF HEAL. Isso fará com que o ArgoCD sincronize automaticamente as mudanças no Git para o cluster e remova recursos que não estão mais no Git.

  - Repository URL: Selecione o repositório hello-manifests que você acabou de adicionar.

  - Revision: HEAD (ou main para a branch principal).

  - Path: hello-app (o diretório dentro do seu repositório hello-manifests onde estão seus manifestos).

  - Cluster: in-cluster (se você estiver implantando no mesmo cluster onde o ArgoCD está rodando) ou selecione o cluster de destino.

  - Namespace: default (ou o namespace onde você quer implantar a aplicação).
![alt text](images/image-5.png)
![alt text](images/image-6.png)
- Clique em CREATE.

- O ArgoCD irá agora detectar os manifestos no seu repositório hello-manifests e iniciará o processo de sincronização, implantando o hello-app-deployment e o hello-app-service no seu cluster Kubernetes. Você poderá ver o status da aplicação na interface do ArgoCD.

# 3. Acessar e testar a aplicação localmente
Esta etapa final verifica se sua aplicação foi implantada com sucesso e se a pipeline de CI/CD está funcionando como esperado.

## 3.1 Criando o port-forward 
- Usando o port-forward para rotear as portas do serviço, acesse via navegador: http://localhost:8080/
Assumindo que sua aplicação hello-app foi implantada no namespace default e o serviço se chama hello-app-service, você pode usar o kubectl port-forward para acessar a aplicação localmente:

- Verifique se o serviço está rodando:
```bash
kubectl get svc -n default
```
- Você deve ver hello-app-service na lista.
Encaminhe a porta:
```bash
kubectl port-forward svc/hello-app-service 8080:80 -n default
```
- Este comando encaminhará o tráfego da porta 8080 da sua máquina local para a porta 80 do serviço hello-app-service dentro do cluster.

- Acesse no navegador abrindo seu navegador e acesse http://localhost:8080/. Você deverá ver a mensagem:
```html
{"message": "Hello World"}
```
|      |       ||||
|-------|-----|:----------------------------------------:|-------------:|-------| 
|     | |![alt text](images/image-7.png)|||
- Isso confirma que sua aplicação está rodando e acessível.

## 3.2 Alterando o repositório 
  - Para mudar a mensagem da aplicação, modifique a mensagem dentro do código python de "Hello World" para qualquer outra mensagem e verifique se após o processo de CI/CD a imagem foi atualizada no ambiente Kubernetes.
  
  - No seu repositório hello-app (localmente), edite o arquivo main.py e altere a mensagem:

### main.py
```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def root():
    # Nova mensagem da aplicação
    return {"message": "Olá do CI/CD com ArgoCD!"}
```

  - Commite e faça o push da alteração:
```bash
cd /caminho/para/seu/hello-app
git add main.py
git commit -m "Update message to Olá do CI/CD com ArgoCD!"
git push origin main
```
## 3.3 Monitore o GitHub Actions:
  - Vá para o seu repositório hello-app no GitHub, na aba Actions.

  - Você verá um novo workflow sendo executado. Monitore o progresso.

  - A pipeline irá construir uma nova imagem Docker com a nova tag (SHA do commit).

  - Após isto, Fará o push dessa imagem para o Docker Hub e irá clonar o repositório hello-manifests.

  - Atualizar o arquivo hello-app/deployment.yaml com a nova tag da imagem.

  - Fazer um commit e push dessa alteração para o hello-manifests.

## 3.4 Monitore o ArgoCD:
  - Vá para a interface do ArgoCD. Você verá que a aplicação hello-app entrará em estado OutOfSync (Fora de Sincronia) porque o repositório de manifestos foi atualizado.

  - Devido à política de sincronização automática (Automatic com SELF HEAL), o ArgoCD detectará a mudança e iniciará automaticamente a sincronização.

  - Aguarde até que a aplicação volte para o estado Synced (Sincronizado) e Healthy (Saudável). Isso significa que o Kubernetes atualizou o deployment com a nova imagem.

## 3.5 Verifique a aplicação atualizada:

  - Mantenha o kubectl port-forward rodando (se ele parou, execute novamente).

  - Atualize a página no seu navegador (http://localhost:8000/).

  - Você deverá ver a nova mensagem:
```html
{"message": "Olá do CI/CD com ArgoCD!"}
```

- Configuramos com sucesso uma pipeline de CI/CD completa usando FastAPI, Docker, GitHub Actions e ArgoCD. Agora, qualquer alteração no seu código FastAPI será automaticamente construída, publicada e implantada no seu cluster Kubernetes.

Entregas Esperadas
Para validar a implementação da pipeline de CI/CD, você precisará fornecer as seguintes evidências:



✅ Link do repositório Git com a aplicação FastAPI + Dockerfile + GitHub Actions:

Forneça o link para o seu repositório hello-app no GitHub. Este repositório deve conter o main.py, Dockerfile, requirements.txt e a pasta .github/workflows com o arquivo main.yml do GitHub Actions.

✅ Link do repositório com os manifests (deployment.yaml, service.yaml):

Forneça o link para o seu repositório hello-manifests no GitHub. Este repositório deve conter a estrutura de pastas (ex: hello-app/) com os arquivos deployment.yaml e service.yaml.

✅ Evidência de build e push da imagem no Docker Hub:

Uma captura de tela ou link direto para a página da sua imagem no Docker Hub, mostrando que a imagem seu-usuario-docker/hello-app (com as tags latest e a tag do SHA do commit) foi publicada com sucesso.

![alt text](images/image-16.png)

Alternativamente, uma captura de tela do log do GitHub Actions mostrando o passo de "Build and push Docker image" concluído com sucesso.

![alt text](images/image-17.png)

✅ Evidência de atualização automática dos manifests com a nova tag da imagem:

Uma captura de tela do histórico de commits do seu repositório hello-manifests no GitHub, mostrando um commit automático feito pelo GitHub Actions que atualizou a tag da imagem no deployment.yaml.

Ou, uma captura de tela do log do GitHub Actions mostrando o passo de "Update ArgoCD manifests" (ou similar) que realizou o push para o repositório de manifests.

✅ Captura de tela do ArgoCD com a aplicação sincronizada:

Uma captura de tela da interface do ArgoCD mostrando o status da sua aplicação hello-app como Synced (Sincronizado) e Healthy (Saudável), indicando que a implantação foi bem-sucedida.

![alt text](images/image-18.png)

✅ Print do kubectl get pods com a aplicação rodando:

![alt text](images/image-20.png)

Uma captura de tela do seu terminal executando o comando kubectl get pods -n <seu-namespace> (ex: kubectl get pods -n default) e mostrando o pod da sua aplicação hello-app-deployment em estado Running.

![alt text](images/image-8.png)

✅ Print da resposta da aplicação via curl ou navegador:

![alt text](images/image-9.png)

Uma captura de tela do seu navegador acessando http://localhost:8000/ (após executar o kubectl port-forward) e exibindo a mensagem de resposta da sua aplicação FastAPI (ex: {"message": "Olá do CI/CD com ArgoCD!"}).

![alt text](images/image-11.png)


Alternativamente, uma captura de tela do seu terminal executando curl http://localhost:8080/ e mostrando a mesma mensagem de resposta.
![alt text](images/image-12.png)