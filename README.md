# DocVault Pro: End-to-End Cloud-Native Project

A fully integrated DevOps project simulating real-world CI/CD workflows, infrastructure provisioning, monitoring, and automation — built for aspiring DevOps engineers.

**Author:** Tinkal Kumar | **Developer** | [Portfolio](https://tinkal.vercel.app/) | [GitHub](https://github.com/MERNDevTinkal?tab=repositories)

---

## Project Overview

This DevOps DocVault Pro enables users to
- Upload input files through a frontend hosted on S3 + CloudFront
- Automatically trigger processing via Lambda and S3 events
- Use pre-signed URLs for secure uploads
- Deploy and manage infrastructure using Terraform
- Automate pipelines via GitHub Actions
- Monitor health and logs via CloudWatch

---

## The flow (How It Works)

1. User visits frontend site through browser.
2. Navigates through all the sections.
3. Makes the payment and uploads the screenshot / .pdf file.
3. Uploaded input file is converted to pre-signed URL and placed in S3 bucket.
4. S3 event triggers → Lambda execution.
5. Lambda processes the file and logs the result in CloudWatch.
6. SNS alert sent to the owner after successful processing.

---


## Tech Stack

| Layer             | Tools & Services                        |
|------------------|------------------------------------------|
| Frontend         | HTML/CSS + S3 + CloudFront               |
| Backend (Event)  | AWS Lambda (Python)              |
| Infrastructure   | Terraform (modular setup & remote backend)                |
| CI/CD            | GitHub Actions (Workflows & Triggers)    |
| Monitoring       | CloudWatch (Logs, Alarms, Dashboard)     |
| Notification     | SNS (Email alerts for file uploads)      |
| Security         | IAM Roles, Policies, Bucket Permissions  |

---


## What's covered in this DevOps Accelerator Platform


#### Infrastructure Auto-Provisioning with Terraform

- Automated infra management using Terraform.

- Remote backend configured with S3 for state file and DynamoDB for state locking.


#### End-to-End CI/CD Automation with GitHub Actions

- Fully automated workflows for:
	
	- Frontend deployment (S3 + CloudFront)
	
	- Backend Lambda packaging & deployment
	
	- Terraform infrastructure provisioning
	
- Separate pipelines for each component.


#### Cloud-Native Hosting (No Server Management Needed)

- Static frontend hosted on S3 + CloudFront CDN for global delivery.

- Backend logic served through AWS Lambda using REST APIs.

- Everything is serverless-first, cost-efficient, and easily scalable.


#### Secure File Upload Workflow Using Pre-Signed URLs

- Users securely upload files using pre-signed S3 URLs.

- Upload triggers processing Lambda without exposing S3 directly.


#### Automated Monitoring & Alerting

- AWS CloudWatch monitors backend Lambda executions.

- AWS SNS notifies on every successful file processing event.

- Auto-alerts configured for error detection and operational visibility.


#### Modular Gigs to Extend the Platform

- Easily extendable with plug-and-play gig modules like:

	- Project Generator

	- QA Bot

- New gigs can be added without disrupting the core pipeline.


#### Organized Folder Structure for Scalability

- Clean, modular repo layout separating infra, frontend, backend, and workflows.

- Easy to replicate in other AWS accounts.


---


## Folder Structure

```
DocVault
├── .github
│   └── workflows
│       ├── backend-deploy.yml
│       ├── frontend.yml
│       └── terraform.yml
├── backend
│   └── lambda
│       ├── generate-presigned-url
│       │   ├── lambda.zip
│       │   └── main.py
│       └── process-uploaded-file
│           ├── lambda.zip
│           └── main.py
├── frontend
│   └── index.html
├── gigs
│   ├── project-generator
│   └── qa-bot
├── infra
│   └── terraform
│       ├── main.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       └── variables.tf
└── README.md
└── .gitignore

```

## Deployment Instructions

### 1. Prerequisites

- AWS CLI configured locally (`aws configure`)

- Terraform should be installed

- Node.js or Python (depending on Lambda)

- GitHub repository created (for CI/CD)


### 2. Infrastructure Setup with Terraform

- Always navigate to the terraform folder when running below commands in same sequence:
	- `terraform init`
	
		-  To initialize and setup everything. [*Need to run this whenever new changes are made to terraform files or its dependent resources like lambda folders in backend.*]
	- `terraform validate`
		- To verify if the configs are corrected defined or not.
	- `terraform plan`
		- To confirm what all resources are going to be built.

	#### Important note: 
	- Do NOT run `terraform apply`locally.  
	- Need all changes to go through CI/CD so we push to remote directly and apply will run through pipeline.


### 3. GitHub Actions CI/CD

- CI/CD runs on push to `main` branch.

- Auto-deploys updated Lambda code (backend), terraform scripts or frontend.

- Uses GitHub Secrets to authenticate with AWS


---

### 4. Deployment Execution guidance
````md
If you'd like to replicate this project [DevOps Accelerator] on your own AWS account, follow the detailed steps below.

---

##  Prerequisites

- AWS Account (with Administrator Access)
- AWS CLI installed (`aws configure` will be used)
- Git & GitHub account
- Terraform v1.3+ installed
- Node.js (for future extensibility)

---

##  Set Up AWS Credentials

1. Log into AWS Console → IAM → **Create User**
2. After user creation, under the **Users** tab:
   - Click your newly created user
   - Go to **Security credentials** → Create **Access Key**
   - Skip tags, **download the CSV** (Important: don’t close until downloaded)
3. Assign permissions:
   - Go to **Permissions** → Add permissions
   - Choose **Attach policies directly**
   - Search for `AdministratorAccess` and attach
4. In terminal, run:
   ```bash
   aws configure
````

* Enter Access Key ID and Secret Key from the CSV
* Leave region/format blank (or use `us-east-1`)

---

##  Clone the DevOps Accelerator Repository

```bash
mkdir my-devops-project && cd my-devops-project
git init
git clone git@github.com:MERNDevTinkal/DocVault.git .
```

---

## Set Up GitHub Repository

1. Create a new GitHub repo (do **not** initialize with README).
2. Add your new repo as remote origin:

   ```bash
   git remote add origin git@github.com:MERNDevTinkal/DocVault.git
   ```

---

##  Add GitHub Repository Secrets

Go to:
**GitHub → Repo → Settings → Secrets → Actions → New repository secret**

| Secret Name             | Value / Description                               |
| ----------------------- | ------------------------------------------------- |
| `AWS_ACCESS_KEY_ID`     | Your AWS IAM access key                           |
| `AWS_SECRET_ACCESS_KEY` | Your AWS IAM secret key                           |
| `AWS_REGION`            | `us-east-1`                                       |
| `LAMBDA_FUNCTION_NAME`  | `process-uploaded-file`                           |
| `FRONTEND_BUCKET_NAME`  | Your Frontend Bucket Name                         |
| `UPLOAD_BUCKET_NAME`    | York Upload Bucket Name                           |

 **Later (after Terraform apply):**

* Add `CLOUDFRONT_DIST_ID` (found in AWS → CloudFront → Distributions)

#### Important Note:
* S3 bucket names have to be *globally unique*, make sure to **change your bucket name while trying to pushing the changes** for the 1st time. Other services like lambda/cloudfront/dynamoDB etc can have same names if AWS account is different.

---

##  Prepare Lambda Deployments

Since Lambda code is already hardcoded in Terraform, zip the contents to deploy manually:

```bash
cd backend/lambda/process-uploaded-file
zip -r lambda.zip .

cd ../generate-presigned-url
zip -r lambda.zip .
```

>  After any change to `main.py`, **delete the old `lambda.zip`** and re-zip before pushing.

---

##  Create Terraform State Infrastructure (Manually)

These resources are required **before** `terraform init`:

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket devops-accelerator-platform-tf-state \
  --region us-east-1

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name devops-accelerator-tf-locker \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

##  Run Terraform Commands

```bash
cd infra/terraform
terraform init
terraform validate
terraform plan
```

If successful:

```bash
git push -u origin main
```

---

##  Git Push Troubleshooting (File Size Errors)

If you hit a `.terraform/` size error:

```bash
echo ".terraform/" >> .gitignore
git rm -r --cached infra/terraform/.terraform
git commit -m "Remove .terraform directory"
```

If file is still too large (over 100MB):

```bash
# macOS
brew install git-filter-repo

# Ubuntu/Linux
sudo apt update
sudo apt install python3-pip -y
pip3 install git-filter-repo

git filter-repo --force --path infra/terraform/.terraform/ --invert-paths

# Reconnect your repo
git remote add origin git@github.com:MERNDevTinkal/capstone_Project.git
git push --force --set-upstream origin main
```

>  Future pushes may hit the same issue. Either:
>
> * Use `git filter-repo` + force push
> * Or manually delete the `.terraform/` folder each time before pushing

---

##  Validate Your Deployment

After pushing, GitHub Actions will automatically:

* Deploy frontend to **S3 + CloudFront**
* Deploy backend Lambda functions
* Set up Terraform-managed infrastructure

---

##  Verify Resources in AWS Console

You should now see the following:

* **3 S3 Buckets**:

  * Terraform state
  * Frontend hosting
  * File upload

* **2 Lambda Functions**:

  * `generate-presigned-url`
  * `process-uploaded-file`

* **1 API Gateway** with POST method

* **1 SNS Topic** (`docVault-upload-notification-topic`)

  * Check your inbox and **confirm subscription**

* **1 CloudFront Distribution**

  * This hosts your website

>  Tip: In AWS Console, double-click the "Created" column to sort newest resources on top.

---

##  Final Testing

### 1. Open Website via CloudFront

Copy the `cloudfront_url` from Terraform output, prefix with `https://`, and paste in your browser.

---

### 2. Update API Gateway Throttling

AWS Console → API Gateway:

* Select your API
* Left panel → **Protect** → Throttling
* Edit **Default Stage**:

  * **Burst limit**: `100`
  * **Rate limit**: `200`
* Save changes and wait 2 minutes

---

### 3. Upload File (JPG/PNG/PDF)

Visit your CloudFront-hosted site and upload a file.
If upload fails:

* Increase burst/rate limits
* After success, **reduce both limits back to 0** (to avoid costs)

---

### 4. Check CloudWatch Logs

Go to AWS Console → Lambda → `process-uploaded-file`:

* Monitor → View Logs in CloudWatch
* Check logs for uploaded file info

> For additional metadata (name/email), repeat with `generate-presigned-url` Lambda

---

### 5. Confirm Email Notification

If logs show file was processed, you should receive a confirmation email (via SNS Topic).

---

##  You're Done!

You’ve successfully deployed a **production-grade Application **, with:

*  Auto-scalable infrastructure (via Terraform)
*  CI/CD pipelines (GitHub Actions)
*  Lambda-powered backend (serverless)
*  Frontend hosted via S3 + CloudFront
*  Monitoring + Email notifications via CloudWatch + SNS

*Happy DevOps-ing!*
