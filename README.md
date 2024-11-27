# Rocking Terraform
- **Terraform**과 AWS 인프라 구축 연습을 하기 위해 혼자서 진행한 프로젝트입니다.

# 주요 기능
## 1. Infra Provisioning
아래 사진과 같은 인프라를 프로비저닝합니다.
![demo11 (2) drawio (2)](https://github.com/user-attachments/assets/a9dc4660-44f6-4b7a-8ce7-3ed446acbf39)
- **3계층 아키텍처**를 구성했으며, **가용성**을 위해 ap-northeast-2a와 ap-northeast-2c 가용 영역을 사용했습니다.
- Private Subnet은 **AWS EKS**를 이용해 관리합니다. EKS에서 실행되는 서버에서는 DB에 대해 CRUD 작업을 수행할 수 있습니다.
- EKS Cluster에는 aws-loadbalancer-controller, prometheus, grafana Pod를 배포합니다.

## 2. Docker
- RDS 프로비저닝이 완료되면 db의 endpoint, name, user, password를 json 파일로 만들어 yyk-server/에 저장합니다.
- 이 파일의 내용은 app.py에서 DB와 통신할 때 이용되고, Dockerfile을 통해 도커 이미지에 복사됩니다.
- app.py는 RDS에 대해 CRUD 작업을 수행할 수 있는 Flask 서버입니다.
- Terraform의 local_exec provisioner가 Docker build와 Docker push 명령을 수행합니다.

## 3. Prometheus, Grafana
- aws loadbalancer controller에 의해 prometheus, grafna에 접근할 수 있는 ALB (Application Load Balancer)가 프로비저닝됩니다.
- 이 ALB를 Route53에서 레코드 대상으로 설정하면 웹 브라우저에서 Prometheus와 Grafana에 접근할 수 있습니다.
- 제 경우 호스팅 영역은 dududrb.shop이며, 레코드는 각각 prometheus.dududrb.shop, grafana.dududrb.shop으로 설정했습니다.

### prometheus.dududrb.shop에서 프로메테우스에 접속한 모습
![download](https://github.com/user-attachments/assets/c27a7764-f65c-490c-9eda-641bb6818a00)

### grafana.dududrb.shop에서 프로메테우스에 접속한 모습
![download (1)](https://github.com/user-attachments/assets/e65902fb-26e8-46a8-aab5-5915dac490c8)

### clusterIP의 도메인을 통해 그라파나에서 프로메테우스의 메트릭을 수집합니다.
![download (2)](https://github.com/user-attachments/assets/644d5f29-894e-4b6f-9cd2-f215b136ae39)
![download (3)](https://github.com/user-attachments/assets/eb2d6ef2-d9a8-46f4-953c-1dd22343b568)

### Grafana 대시보드 템플릿을 이용하여 현재 클러스터 모니터링 환경을 구축했습니다.
![download (4)](https://github.com/user-attachments/assets/af55737c-a216-47c3-ad63-da5da1701f46)

## 4. CRUD
Flask Server 또한 ingress를 이용해 crud.dududrb.shop 레코드에 배포했습니다.

### health check
/health 경로에 접근하여 정상 응답을 보내는지 확인합니다.
![health](https://github.com/user-attachments/assets/bf558bbb-1765-40e4-b893-a0b9ae12cb01)

### CREATE
POST 메서드를 사용하여 test_item1, test_item2를 생성합니다.
![CREATE](https://github.com/user-attachments/assets/a152092d-7fce-48ea-b1de-0f22d2cefb8f)

### READ
GET 메서드를 사용하고/items 경로에 접근하여 현재 MySQL에 저장된 내용을 확인합니다.
![READ](https://github.com/user-attachments/assets/dfde6db3-b8da-43a4-b6a6-e521196bcad8)

### UPDATE
PUT 메서드를 사용해 id가 2인 값의 name을 “updated_item2”로 변경했습니다.
READ 결과 정상적으로 반영되었습니다.
![download (5)](https://github.com/user-attachments/assets/68c5575d-bd56-4172-88e2-e01f7f2ff201)

### DELETE 
DELETE 메서드를 사용하여 id가 2인 값을 제거했습니다.
READ 결과 id가 1인 값만 남아 있습니다.
![download (6)](https://github.com/user-attachments/assets/546a0701-f8a8-4137-b08d-44c9853cc9bc)

# 리소스 제거
리소스를 제거할 땐 delete_resource 파일을 실행 후 terraform destroy 명령을 실행합니다.
