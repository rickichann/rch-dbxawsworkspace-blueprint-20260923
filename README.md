# Databricks on AWS — workspace blueprint

Reusable Terraform template for standing up a Databricks workspace on AWS with a
customer-managed VPC and Unity Catalog. Ships two environments, `dev` and `prod`,
each with its own state bucket and its own VPC CIDR.

This checkout is wired to the `rch` AWS CLI profile in `ap-southeast-1`, and both
environments target that same AWS account. That is fine for a sandbox. For a real
deployment, put dev and prod in **separate AWS accounts** with separate profiles, so a
mistake in dev cannot reach prod — change `aws_profile` in the six `terraform.tfvars`
and the `profile` in the six `backend "s3"` blocks. The variable defaults in
`variables.tf` are intentionally left generic so that a missing tfvars entry fails
loudly instead of silently picking an account.

Nothing in here is company-specific. Every name is derived from two variables,
`company_name` and `environment`. Placeholders use the literal string `company`.

```
terraform/envs/
├── dev/
│   ├── create-state-bucket.sh
│   ├── aws-foundation/          # Layer 1 - VPC, subnets, NAT, security group, DBFS root bucket
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
| Resource prefix      | `{company_name}-dbx-{environment}`                 | `rch24company-dbx-prod`                      |
| DBFS root bucket     | `{prefix}-root-bucket`                             | `rch24company-dbx-prod-root-bucket`          |
| Catalog data bucket  | `{prefix}-catalog-data`                            | `rch24company-dbx-prod-catalog-data`         |
| Unity Catalog        | `{company_name}_dbx_{environment}` (underscores)    | `company_dbx_prod`                      |
| Workspace name       | `{prefix}`                                         | `rch24company-dbx-prod`                      |
| State bucket         | `{company_name}-dbx-{environment}-terraform-state` | `rch24company-dbx-prod-terraform-state`      |
| State key            | `{environment}/{layer}/terraform.tfstate`          | `prod/aws-foundation/terraform.tfstate` |

Replace `company` with the real short name and every resource above follows.

## Using the template for a new company

1. Copy this repo.
2. Per environment, set `company_name`, `environment`, `aws_region`, `aws_profile` in all three `terraform.tfvars`.
3. Per environment, update the `backend "s3"` block in all three `providers.tf`. Backends cannot read variables, so this is the one place you edit HCL directly.
4. Per environment, update the header of `create-state-bucket.sh`.
5. Pick non-overlapping VPC CIDRs. See [CIDR allocation](#cidr-allocation).
6. Export the Databricks service principal credentials as `TF_VAR_databricks_client_id` and `TF_VAR_databricks_client_secret`. Never commit them.
7. Follow `terraform/envs/<env>/README.md` and apply the layers in order.

Values that must be filled in are marked `REPLACE_ME` / `REPLACE_WITH_...` in the tfvars
files, so a forgotten one fails loudly at plan time.

## CIDR allocation

Each environment has its own VPC with its own address range, set in that environment's
`aws-foundation/terraform.tfvars`. Only the second octet differs, which keeps the two easy
to tell apart in route tables and flow logs.

|                      | prod             | dev              |
|----------------------|------------------|------------------|
| VPC                  | `10.174.0.0/16`  | `10.175.0.0/16`  |
| Public subnet, AZ a  | `10.174.0.0/24`  | `10.175.0.0/24`  |
| Public subnet, AZ b  | `10.174.1.0/24`  | `10.175.1.0/24`  |
| Private subnet, AZ a | `10.174.16.0/20` | `10.175.16.0/20` |
| Private subnet, AZ b | `10.174.32.0/20` | `10.175.32.0/20` |
| VPC addresses        | 65,536           | 65,536           |
| Per private subnet   | 4,096            | 4,096            |

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

Adding a third environment? Take the next free second octet, `10.176.0.0/16`, and check it
against existing VPCs and on-prem ranges in the target account before applying.

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
