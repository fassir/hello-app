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