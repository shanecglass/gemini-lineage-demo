# Gemini Lineage Demo - Preparing your data with AI & building lineage into your AI workflows
## Overview
This repo provides an example of how Google Cloud's pretrained AI models, such as the Translation API and the Vision API, can be used to clean and prepare multimodal data for analysis. Additionally, this repo demonstrates how to build a RAG architecture using BigQuery's integration with Gemini 1.0 Pro and Pro Vision models, and how to use an LLM to resolve customer service issues. The following instructions should help you get started. It is intended to demonstration:
1. **How to build a RAG architecture in BigQuery** \
This app will deploy a query (sp_generate_email) in the `cymbal_sports_marketing` dataset that can be thought of as a RAG architecture built in BigQuery. It pulls enterprise data from a variety of sources to provide context for the Gemini 1.0 Pro model, which produces a customized output specifically for this customer.
2. **Demonstrate how to use Remote Functions with BigQuery to get additional capabilities** \
BigQuery's serverless scalability unlocks a world of potential use cases. However, any workflow that uses only BigQuery will have inherent limitations. Combining BigQuery with a Cloud Function as a remote funtion to combine the power and simplicity of BigQuery with the flexibility of Python.
3. **Begin to implement "prompt & response lineage" by capturing the prompt and response (along with associated metadata) to a Pub/Sub topic** \
This is a first step to implementing full lineage and governance for workloads that use LLMs. The Pub/Sub topics used in this app write to BigQuery, allowing you to analyze LLM usage over time.
4. **How Terraform can be used to support simplified infrastructure deployments** \
Terraform can be used to scalably manage infrastructure for deployments, specifically for repeatable tasks such as launching LLM apps with varying use cases.

# Deploying the app
## Setup
**Note** \
Before you start: Though it's not a requirement, using a new GCP project for this demo is easiest. This makes cleanup much easier, as you can delete the whole project to ensure all assets are removed and it ensures no potential conflicts with existing resources. You can also remove resources by running `terraform destroy` after you deploy the resources, but it will miss some of the resources deployed by Terraform.

### 0. Clone this repo in Cloud Shell
#### 1. You'll need to set your Google Cloud project in Cloud Shell, clone this repo locally first, and set the working directory to this folder using the following commands.
```
gcloud config set project <PROJECT ID>
git clone https://github.com/shanecglass/gemini-lineage-demo
cd gemini-lineage-demo
```
#### 2. Enable the Cloud Resource Manager API
Check to make sure the [Cloud Resource Manager API](https://console.cloud.google.com/apis/library/cloudresourcemanager.googleapis.com) is enabled

### 1. Setup your infrastructure
This app uses Cloud Run, Cloud Build, BigQuery, and PubSub. Run the following to execute the Terraform script to setup everything.

#### 1. Intialize Terraform
First, initialize Terraform by running
```
terraform init
```
#### 2. Verify that the Terraform configuration has no errors
Run the following:
```
terraform validate
```
If the command returns any errors, make the required corrections in the configuration and then run the terraform validate command again. Repeat this step until the command returns `Success! The configuration is valid.`

#### 3. Review resources
Review the resources that are defined in the configuration:
```
terraform plan
```

#### 4. Deploy the Terraform script

```
terraform apply
```

When you're prompted to perform the actions, enter the project ID for your Google Cloud Project, then enter `yes`. Terraform displays messages showing the progress of the deployment.

If the deployment can't be completed, Terraform displays the errors that caused the failure. Review the error messages and update the configuration to fix the errors. Then run `terraform apply` command again. For help with troubleshooting Terraform errors, see [Errors when deploying the solution using Terraform](https://cloud.google.com/architecture/big-data-analytics/analytics-lakehouse#tf-deploy-errors).

After all the resources are created, Terraform displays the following message:
```
Apply complete!
```

The Terraform output also lists the following additional information that you'll need:
- A link to the Cloud Run app that was created
- The link to open the BigQuery editor for some sample queries

## Use the demo app
### 2. **Walkthrough Guide for Walkthrough Guide for Data Preparation notebook**
Complete the steps listed in the `Walkthrough Guide for Data Preparation` notebook under the "shared notebooks" section in your BigQuery explorer. This will provide all the data cleaning needed to use the data

### 3. **Invoke the RAG architecture query**
From the BigQuery console SQL Workspace, call the [`sp_generate_email`](./src/templates/sql/generate_email.sql) stored procedure to invoke the RAG architecture in BigQuery and get the email output. You can also do so by running the following query:

```
CALL `cymbal_sports_marketing.sp_generate_email`();
```

### 4. **Use a remote function to analyze customer data!**
Bonus points if you complete this one, since it wasn't shown on screen! Call the `sp_invoke_function` stored procedure to invoke the remote function and see how this can be used to analyze customer review data proactively and at scale.

```
CALL `cymbal_sports_marketing.sp_invoke_function`();
```
