AWS Infrastructure Automation with Terraform
A three-tier web application on AWS. All infrastructure is written as code in Terraform, deployments run through a GitHub Actions pipeline, and the environment is monitored with CloudWatch.
Built as a technical assignment for 8Byte.ai.
The application itself is deliberately small, a simple Express API with three endpoints, because the brief said application logic was not the priority. The work here is the infrastructure around it.
________________________________________
Architecture
A request comes in from the internet and hits an Application Load Balancer sitting in public subnets. The load balancer forwards it to an EC2 instance running the app in Docker, which sits in a private subnet with no public IP. The app then queries an RDS PostgreSQL database, also in private subnets and not reachable from the internet.
Everything runs in ap-south-1 (Mumbai), chosen for proximity to users.
Other services used: ECR to store the container image, Secrets Manager for the database password, CloudWatch for metrics and alarms, SNS for email notifications, and SSM for shell access.
________________________________________
Setup
You need Terraform, the AWS CLI configured with credentials, and Docker.
1. Create the container registry first, because the server pulls an image when it boots:
bash
cd terraform
terraform init
terraform apply -target=aws_ecr_repository.app
2. Build and push the image:
bash
cd ../app
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com
docker build -t 8byte-devops-app .
docker tag 8byte-devops-app:latest <ecr-url>:latest
docker push <ecr-url>:latest
3. Build everything else:
bash
cd ../terraform
terraform plan
terraform apply
4. Check it works. The load balancer URL comes out in the Terraform outputs.
bash
curl http://<alb-dns-name>/health
curl http://<alb-dns-name>/ready
curl http://<alb-dns-name>/items
To run it locally instead, docker compose up --build in the app folder starts the app against a local Postgres container.
To tear everything down, terraform destroy.
________________________________________
Architecture decisions
EC2 instead of ECS or EKS. The brief allowed any of the three. EKS would have meant a control plane, node groups and ingress controllers, which is a lot of moving parts for a single container and more than I could set up and properly understand in the time available. ECS would have been the better middle ground and would have avoided the deployment problem described further down. What I gave up by choosing EC2: rolling deployments, self-healing and horizontal scaling.
Public and private subnets. Only the load balancer is public. The app server and the database have no public IP addresses at all. A subnet is only public because its route table sends internet traffic to an internet gateway, not because of any setting on the subnet itself. The private route table sends that same traffic to a NAT gateway, which lets the server download updates and images but blocks anything coming in.
Two availability zones. Subnets are spread across two physically separate datacentres, so losing one does not take everything down. The zones are looked up rather than hardcoded, so the code works in other regions.
One NAT gateway, not two. One per zone would be more resilient. One costs about half as much, and it is the single biggest line item in the bill. A deliberate cost tradeoff for a demo environment.
________________________________________
Security
The database password never appears anywhere. RDS generates it itself and writes it straight into Secrets Manager. Terraform never receives the value, so it never lands in the state file or in Git. The server fetches it when it boots.
No AWS keys on the server. The EC2 instance asks AWS directly for temporary credentials, which AWS rotates automatically. There are no access keys sitting on disk.
Least privilege on the secret. The policy letting the server read from Secrets Manager is scoped to one specific secret, not a wildcard. It can read the one password it needs and nothing else.
Security groups reference each other. The load balancer accepts port 80 from the internet, the app accepts port 3000 only from the load balancer, and the database accepts port 5432 only from the app. Because the rules reference groups rather than IP addresses, replacing an instance does not break anything. There is no network path from the internet to the database.
No SSH. Shell access goes through SSM Session Manager, so port 22 stays closed and there are no key pairs to lose.
Other measures. The database disk is encrypted. SQL queries use parameters rather than string concatenation, so input cannot change the query. The container runs as a non-root user. Dependencies are scanned with npm audit and the image with Trivy.
Shortcuts I took
Deliberate, and would not go to production:
•	The Terraform IAM user has AdministratorAccess. It should be scoped to what Terraform actually manages.
•	skip_final_snapshot and deletion_protection are set so the environment can be destroyed cleanly after the demo.
•	The load balancer is HTTP only, no TLS certificate.
•	The database connection encrypts traffic but does not verify the certificate.
•	The pipeline uses stored AWS credentials rather than OIDC. See known issues.
________________________________________
CI/CD pipeline
Four jobs, each running only if the previous one passed.
Pull requests run tests and a dependency audit, nothing else. When code merges to main, the pipeline builds the Docker image, scans it with Trivy, and pushes it to ECR. Then it deploys to staging. Production is gated behind a manual approval using a GitHub Environment with a required reviewer.
The two scans catch different things. npm audit finds vulnerable libraries in the app. Trivy finds vulnerable operating system packages inside the image.
Trivy currently reports findings without failing the build. In production it would block the deployment.
________________________________________
Monitoring
Two dashboards, both written in Terraform rather than clicked together in the console, so they are version controlled.
The infrastructure dashboard shows EC2 CPU and network, and RDS CPU, connections, storage and memory. It tells you what is broken.
The application dashboard shows request rate, error counts, response time and healthy host count. It tells you whether users are affected.
Three alarms send email through SNS: EC2 CPU above 80 percent for ten minutes, more than five load balancer 5xx errors in five minutes, and RDS connections above 50.
The 5xx alarm treats missing data as not breaching, because no data means no errors. Without that setting it would go into alarm every time traffic went quiet.
Health checks. /health returns 200 without touching the database, and this is what the load balancer checks. /ready runs an actual query and returns 200 or 503. They are separate on purpose: if the database goes down you do not want the load balancer restarting healthy app servers, because the app is fine and restarting will not fix its dependency.
A log group exists with seven-day retention, though shipping container logs into it is not yet configured.
________________________________________
Backups
RDS takes automated backups with seven-day retention, which allows point-in-time recovery to any second in that window. The backup window sits outside expected peak hours. Storage scales automatically from 20GB up to 50GB, so the database does not quietly fill up.
Not done: cross-region snapshot copies, and actually testing a restore. A backup you have never restored is an assumption, not a guarantee.
________________________________________
Cost
Roughly three dollars a day with everything running. The NAT gateway is about 45 percent of that, the load balancer about 30 percent, RDS about 15 percent, and EC2 about 10 percent.
What I did to keep it down: one NAT gateway instead of two, the smallest instance sizes that work, Graviton for RDS which is cheaper than the x86 equivalent, gp3 storage, storage auto-scaling instead of over-provisioning, an ECR policy that keeps only the last ten images, seven-day log retention, and a billing alert at twenty dollars.
The NAT gateway and load balancer bill by the hour whether or not anyone is using them, so the environment gets destroyed when it is not needed.
________________________________________
Known issues and what I would do next
Terraform state is a local file. It should be in an S3 backend with locking enabled. As it stands there is no locking, no team access, and nothing protecting it from being lost. This is the brief's state management requirement and the biggest gap here.
OIDC is built but not working. The pipeline was meant to authenticate using OIDC federation so no long-lived AWS keys would sit in GitHub. Role assumption kept being denied. I checked the trust policy against the live role using the CLI and everything matched, but I could not isolate the cause in the time available, so I fell back to stored secrets rather than ship a broken pipeline. The role and trust policy are still in github_oidc.tf. Fixing this is my first priority, because stored keys are long-lived and stay valid until someone revokes them.
Deployments cause brief downtime. The staging deploy stops the running container before starting its replacement, and does not check that the new one came up. During one deploy the app went down while the pipeline reported success. The proper fix is a platform with rolling deployments and health-gated cutover, which is what ECS provides.
One instance, no autoscaling. A failed instance is not replaced automatically, and the setup cannot scale horizontally.
No HTTPS. The load balancer only listens on HTTP.
Logs are not centralised. The log group exists but container logs are only visible on the instance itself.
One environment. Proper separation would mean separate AWS accounts, not just different variable values.

