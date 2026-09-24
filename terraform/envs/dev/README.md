# Databricks on AWS — `dev` environment

> Template version 2.0.0

Deploys a Databricks workspace on AWS with a customer-managed VPC plus a Unity Catalog,
for the **dev** environment. The `prod` environment is an identical copy under
`terraform/envs/prod/` with its own state bucket and CIDR range.

Every resource is named `{company_name}-dbx-{environment}-<suffix>`, so with
`company_name = "rch24company"` and `environment = "dev"` you get `rch24company-dbx-dev-vpc`,
`rch24company-dbx-dev-root-bucket`, and so on. The Unity Catalog is the exception: it uses
underscores (`rch24company_dbx_dev`) because catalog names are SQL identifiers.

## Layers

```
terraform/envs/dev/
├── create-state-bucket.sh          # S3 bucket for Terraform remote state
├── aws-foundation/                 # Layer 1: VPC, subnets, NAT, S3 endpoint, SG, DBFS root bucket
├── databricks-workspace/           # Layer 2: cross-account IAM, MWS workspace
└── databricks-catalog/             # Layer 3: catalog bucket, storage credential,
                                    #          external location, catalog, schemas, grants
```

Each layer has its own state file and is applied in order. Layer 2 consumes outputs
from layer 1, layer 3 consumes outputs from layer 2.

## Prerequisites

- Terraform >= 1.11 (S3-native state locking needs it). Check with ``terraform version``.
- AWS CLI with a named profile for the target account
- A Databricks account service principal with the **Account Admin** role (OAuth client ID + secret)
- **A Unity Catalog metastore in the workspace's region, assigned to the workspace.** Layer 3 creates a catalog *inside* an existing metastore; it does not create the metastore. Databricks allows one metastore per region per account, so this is deliberately left outside the template — creating one here would conflict on any account that already has it.

Check before running layer 3: account console → **Catalog** → **Metastores**. If the
region has no metastore, create one and assign it to the workspace, then continue. Newer
Databricks accounts often get one created automatically with the first workspace in a
region, which is why this can pass unnoticed until you deploy into a fresh region.

Symptom if it's missing: layer 3 fails on `databricks_storage_credential` or
`databricks_catalog` with a metastore-not-found or permission error.

## What you edit

### 1. Naming and account, in all three `terraform.tfvars`

| Variable       | Purpose                                | Example          |
|----------------|----------------------------------------|------------------|
| `company_name` | Prefix for every resource name         | `company`        |
| `environment`  | `dev` here, `prod` in the prod folder   | `dev`            |
| `aws_region`   | Region to deploy in                    | `ap-southeast-1` |
| `aws_profile`  | AWS CLI profile for the account        | `your-aws-profile`           |
| `common_tags`  | Tags on every resource                 | see file         |

`company_name` and `environment` must be identical across the three layers — they are
what keep the resource names consistent.

### 2. `backend.hcl` in each layer directory

Backends cannot read variables, so bucket, region and profile are supplied at init time
instead. Copy `backend.hcl.example` from the repo root into each of the three layer
directories and fill it in. `backend.hcl` is gitignored.

```hcl
bucket  = "rch24company-dbx-dev-terraform-state"
region  = "ap-southeast-1"
profile = "your-aws-profile"
```

The state key stays in `providers.tf`, since it is structural rather than deployment
specific. Initialise with:

```powershell
terraform init -backend-config=backend.hcl
```

### 3. `create-state-bucket.sh` header

Set `COMPANY_NAME`, `ENVIRONMENT`, `REGION`, `PROFILE`. The bucket name is derived as
`{COMPANY_NAME}-dbx-{ENVIRONMENT}-terraform-state`.

### 4. Network ranges, in `aws-foundation/terraform.tfvars`

`vpc_cidr`, `public_subnet_cidrs`, `private_subnet_cidrs`, `availability_zones`.
Sizes expected by this blueprint: VPC `/16`, public subnets `/24`, private subnets `/20`.
The tracked tfvars carry `REPLACE_ME/16` style placeholders; put the real ranges in the
gitignored `terraform.auto.tfvars`. Keep them non-overlapping with the other environment
and anything you might peer with, and make sure the AZs belong to `aws_region`.

### 5. Cross-layer values

| File                                   | Variable                                             | Source                     |
|----------------------------------------|------------------------------------------------------|----------------------------|
| `databricks-workspace/terraform.tfvars`| `databricks_account_id`                               | accounts.cloud.databricks.com |
| `databricks-workspace/terraform.tfvars`| `vpc_id`, `private_subnet_ids`, `security_group_id`   | `aws-foundation` outputs   |
| `databricks-workspace/terraform.tfvars`| `root_bucket_name`                                    | leave `""` to auto-derive  |
| `databricks-catalog/terraform.tfvars`  | `databricks_account_id`                               | same as above              |
| `databricks-catalog/terraform.tfvars`  | `databricks_workspace_url`, `databricks_workspace_id` | `databricks-workspace` outputs |
| `databricks-catalog/terraform.tfvars`  | `catalog_schemas`                                     | your choice                |

### 6. Credentials — environment variables only, never in files

**PowerShell:**
```powershell
$env:TF_VAR_databricks_client_id     = "your-service-principal-client-id"
$env:TF_VAR_databricks_client_secret = "your-service-principal-client-secret"
```

**Bash:**
```bash
export TF_VAR_databricks_client_id="your-service-principal-client-id"
export TF_VAR_databricks_client_secret="your-service-principal-client-secret"
```

To create them: accounts.cloud.databricks.com → **User management** → **Service principals** →
select or create one with **Account Admin** → **Secrets** → **Generate secret**. The secret is
shown once.

## Deployment

### Step 0 — state bucket

```bash
bash terraform/envs/dev/create-state-bucket.sh
```

The script is idempotent; re-running it only re-applies versioning, public-access block,
encryption, and tags.

### Step 1 — AWS foundation

```powershell
cd terraform\envs\dev\aws-foundation
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
terraform output
```

Note `vpc_id`, `private_subnet_ids`, `security_group_id`.

### Step 2 — Databricks workspace

1. Paste the Step 1 outputs into `databricks-workspace/terraform.tfvars`
2. Export the Databricks credentials
3. Apply:

```powershell
cd terraform\envs\dev\databricks-workspace
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
terraform output
```

### Step 3 — Unity Catalog

1. Paste `databricks_workspace_url` and `databricks_workspace_id` into `databricks-catalog/terraform.tfvars`
2. Export the Databricks credentials (same as Step 2)
3. Apply:

```powershell
cd terraform\envs\dev\databricks-catalog
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

This creates the catalog data bucket, the IAM role Databricks assumes to reach it, a storage
credential, an external location, the catalog itself (bound to the workspace, granted to
`account users`), and the schemas listed in `catalog_schemas`.

### Step 4 — verify

```powershell
cd terraform\envs\dev\databricks-workspace
terraform output databricks_workspace_url
```

Open the URL and check Catalog Explorer for `{company_name}_dbx_dev` and its schemas.

## Notes

- **IAM propagation**: layers 2 and 3 include a 20s `time_sleep` for IAM eventual consistency. If you still hit role assumption errors, wait a minute and re-apply.
- **S3 bucket names are global**: if `{company_name}-dbx-{environment}-root-bucket` is taken, pick a different `company_name`.
- **State locking** is on via `use_lockfile = true`. Terraform writes a `<key>.tflock` object next to the state file for the duration of a run, so a second concurrent apply fails instead of overwriting state. No DynamoDB table is involved; those backend arguments are deprecated. If a run is killed mid-apply and the lock is left behind, confirm nobody else is running, then `terraform force-unlock <LOCK_ID>`. Use `terraform apply -lock-timeout=5m` if you would rather wait for a lock than fail immediately.
- **Secrets**: `databricks_client_id` / `databricks_client_secret` stay in environment variables. `.gitignore` also excludes `*.auto.tfvars` and `output.txt`.
- **Catalog visibility**: the catalog is owned by the service principal that created it; grants for `account users` are applied so workspace users can read it.

## Teardown

Reverse order:

```powershell
cd terraform\envs\dev\databricks-catalog   ; terraform destroy
cd ..\databricks-workspace                  ; terraform destroy
cd ..\aws-foundation                        ; terraform destroy

# optionally, the state bucket
aws s3 rb s3://rch24company-dbx-dev-terraform-state --force --profile your-aws-profile
```
