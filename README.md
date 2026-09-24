# Databricks on AWS — workspace blueprint

Reusable Terraform template for standing up a Databricks workspace on AWS with a
customer-managed VPC and Unity Catalog. Ships two environments, `dev` and `prod`,
each with its own state bucket and its own VPC CIDR.

This checkout is wired to the `your-aws-profile` AWS CLI profile in `ap-southeast-1`, and both
environments target that same AWS account. That is fine for a sandbox. For a real
deployment, put dev and prod in **separate AWS accounts** with separate profiles, so a
mistake in dev cannot reach prod — change `aws_profile` in the six `terraform.tfvars`
and the `profile` in the six `backend "s3"` blocks. The variable defaults in
`variables.tf` are intentionally left generic so that a missing tfvars entry fails
loudly instead of silently picking an account.

Every name is derived from two variables, `company_name` and `environment`, so
re-pointing the whole stack at a different company is a two-value change per layer.
This checkout has them set to `rch24company` and `dev` / `prod`.

```
terraform/envs/
├── dev/
│   ├── create-state-bucket.sh
│   ├── aws-foundation/          # Layer 1 - VPC, subnets, NAT, S3 endpoint, security group, DBFS root bucket
│   ├── databricks-workspace/    # Layer 2 - cross-account IAM role, MWS workspace
│   ├── databricks-catalog/      # Layer 3 - catalog bucket, storage credential,
│   │                            #           external location, catalog, schemas, grants
│   └── README.md                # step-by-step deploy guide for dev
└── prod/
    └── ... same layout, see prod/README.md
```

The two environments share no state and no resources. Editing one cannot affect the other.

## Naming convention

With `company_name = "rch24company"` and `environment = "prod"`:

| Thing                | Pattern                                            | Result                                  |
|----------------------|----------------------------------------------------|-----------------------------------------|
| Resource prefix      | `{company_name}-dbx-{environment}`                 | `rch24company-dbx-prod`                 |
| Public subnet, AZ 1  | `{prefix}-public-subnet-1a`                        | `rch24company-dbx-prod-public-subnet-1a` |
| Private subnet, AZ 1 | `{prefix}-private-subnet-1b`                       | `rch24company-dbx-prod-private-subnet-1b` |
| Public subnet, AZ 2  | `{prefix}-public-subnet-2a`                        | `rch24company-dbx-prod-public-subnet-2a` |
| Private subnet, AZ 2 | `{prefix}-private-subnet-2b`                       | `rch24company-dbx-prod-private-subnet-2b` |
| DBFS root bucket     | `{prefix}-root-bucket`                             | `rch24company-dbx-prod-root-bucket`          |
| Catalog data bucket  | `{prefix}-catalog-data`                            | `rch24company-dbx-prod-catalog-data`         |
| Unity Catalog        | `{company_name}_dbx_{environment}` (underscores)    | `rch24company_dbx_prod`                 |
| Workspace name       | `{prefix}`                                         | `rch24company-dbx-prod`                      |
| State bucket         | `{company_name}-dbx-{environment}-terraform-state` | `rch24company-dbx-prod-terraform-state`      |
| State key            | `{environment}/{layer}/terraform.tfstate`          | `prod/aws-foundation/terraform.tfstate` |

Change `company_name` and every resource above follows.

Subnet suffixes are `<az index><tier letter>`. The number counts availability zones from
1, following the order of `availability_zones` in the tfvars. The letter is the tier:
`a` for public, `b` for private. Adding a third AZ yields `public-subnet-3a` and
`private-subnet-3b`.

Note the letter is the tier, not the AWS zone letter. `private-subnet-1b` sits in
`ap-southeast-1a`, because it is the private subnet of the first AZ. Check the `Tier` tag
or the `availability_zone` attribute if you need the physical zone.

The Unity Catalog is the one exception to the hyphen convention: catalog names are SQL
identifiers, and hyphens would force `` `rch24company-dbx-prod` `` backticks into every
query.

## Using the template for a new company

1. Copy this repo.
2. Per environment, set `company_name`, `environment`, `aws_region`, `aws_profile` in all three `terraform.tfvars`.
3. Per environment and layer, copy `backend.hcl.example` to `backend.hcl` and fill it in. Backends cannot read variables, so bucket, region and profile are supplied at init time.
4. Per environment, update the header of `create-state-bucket.sh`.
5. Pick non-overlapping VPC CIDRs. See [CIDR allocation](#cidr-allocation).
6. Put the Databricks service principal credentials in a `secrets.auto.tfvars` next to each `databricks-*` layer, or export them as `TF_VAR_databricks_client_id` and `TF_VAR_databricks_client_secret`. Never commit them.
7. Follow `terraform/envs/<env>/README.md` and apply the layers in order.

Values that must be filled in are marked `REPLACE_ME` / `REPLACE_WITH_...` in the tfvars
files, so a forgotten one fails loudly at plan time.

## Keeping deployment values out of git

Everything tracked here is a template: `rch24company`, `your-aws-profile`, `REPLACE_ME`.
Nothing in this repo points at a real account, and that is deliberate so it can be
published and reused.

Terraform loads `*.auto.tfvars` automatically and later files win, so a real deployment
supplies its own values without editing anything tracked. Three gitignored files per
layer, none of which can be committed by accident:

| File | Holds | Needed by |
|-------------------------|--------------------------------------------------------|---------------------|
| `backend.hcl` | state bucket, region, AWS profile | every layer |
| `terraform.auto.tfvars` | `company_name`, `aws_profile`, resource IDs, workspace URL and ID, metastore ID | every layer |
| `secrets.auto.tfvars` | Databricks account ID, SP client ID and secret | `databricks-*` only |

So a layer is initialised and applied like this:

```powershell
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

The upside beyond privacy: the same commit can drive several deployments, and there is no
diff to review every time someone points it at a different account.

## CIDR allocation

Each environment has its own VPC with its own address range, set in that environment's
`aws-foundation/terraform.tfvars`. Only the second octet differs, which keeps the two easy
to tell apart in route tables and flow logs.

Only the prefix sizes are prescribed. The actual ranges are deployment specific and live
in the gitignored `terraform.auto.tfvars`, which is why the tracked tfvars show
`REPLACE_ME/16` and friends.

| Purpose        | Size  | Count       | Addresses | Carries                                   |
|----------------|-------|-------------|-----------|-------------------------------------------|
| VPC            | `/16` | 1 per env   | 65,536    | everything below                          |
| Public subnet  | `/24` | 1 per AZ    | 256       | NAT gateway only                          |
| Private subnet | `/20` | 1 per AZ    | 4,096     | Databricks compute                        |

Public subnets only carry the NAT gateway, so a `/24` is plenty. Private subnets carry
Databricks compute, and their size is the hard ceiling on concurrent cluster nodes — a `/20`
gives roughly 4,000 usable addresses per AZ.

Availability zones are shared between environments (`ap-southeast-1a`, `ap-southeast-1b`).
That is fine: AZs are physical locations, not address space.

**Why the ranges must not overlap.** Two VPCs using identical ranges work fine while they
stay isolated. The moment you connect them — VPC peering, Transit Gateway, a VPN to the
office, or both peering into a shared-services VPC — routing cannot decide which VPC owns an
address that exists in both. AWS rejects peering between overlapping VPCs outright, and the
only fix is renumbering, which means recreating the subnets, the Databricks network config,
and the workspace itself.

Adding an environment? Pick the next free block of the same size and check it against the
existing VPCs and on-prem ranges in the target account first:

```bash
aws ec2 describe-vpcs --region <region> --profile <profile> \
  --query "Vpcs[].{id:VpcId,cidr:CidrBlock}" --output table
```

## Apply order

`aws-foundation` → `databricks-workspace` → `databricks-catalog`. Layer 2 takes `vpc_id`,
`private_subnet_ids` and `security_group_id` from layer 1's outputs; layer 3 takes
`databricks_workspace_url` and `databricks_workspace_id` from layer 2's outputs. The copying
is manual and deliberate — swap in `terraform_remote_state` data sources if you would rather
wire the layers automatically.

Destroy in reverse order.

## Known gaps

- **The committed `.terraform.lock.hcl` files hold `windows_amd64` hashes only.** They were generated on Windows. A colleague on Linux or macOS, or a CI runner, will fail with a missing-checksum error. Fix per layer with `terraform providers lock -platform=windows_amd64 -platform=linux_amd64 -platform=darwin_arm64`, then commit the result.
- **Locking prevents state corruption, not code drift.** `use_lockfile = true` stops two applies colliding, but nothing stops someone applying uncommitted local code, after which state reflects code that is not in git. Until applies run from CI, that is a convention to agree on, not something the tooling enforces.
- **A Unity Catalog metastore is a prerequisite, not created here.** Databricks permits one metastore per region per account, so creating it in a per-environment template would conflict on any account that already has one. See the env READMEs.
- Layers duplicate HCL across `dev` and `prod`. Extracting `terraform/modules/` is the natural next step, but it changes resource addresses, so already-deployed environments would need `terraform state mv`.
- The Databricks-owned AWS account that assumes the Unity Catalog data access role is `414351767826`, correct for commercial regions. Override `databricks_aws_account_id` if your region differs.
