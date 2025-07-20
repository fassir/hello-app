from fastapi import FastAPI

app = FastAPI()


@app.get("/")
async def root():
    # Mensagem inicial da aplicação
    return {"message": "Hello World"}