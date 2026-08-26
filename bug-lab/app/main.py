# verifying the fix works
from fastapi import FastAPI

app = FastAPI()


@app.get("/health")
def health():
    return {"status": "yes"}