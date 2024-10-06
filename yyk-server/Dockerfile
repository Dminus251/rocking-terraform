FROM python:3.9-slim

WORKDIR .

#dependancies
COPY requirements.txt ./

#API server
COPY app.py ./

#Terraform output
COPY terraform_outputs.json ./

#curl http://localhost:5000/health
COPY healthCheck.sh ./


RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 5000

CMD ["python", "app.py"]
