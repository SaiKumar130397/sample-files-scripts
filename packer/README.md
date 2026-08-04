# Build Multi-Cloud Images With Packer

This folder builds Ubuntu 22.04 images for:

- AWS AMI
- Azure managed image
- Google Cloud custom image

The image build runs the repository's root `bootstrap.sh`, so the baked image includes Docker, Jenkins, Terraform, kubectl, Helm, Java, and the matching cloud CLI.

## 1. Install Packer

On macOS:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/packer
```

Check it:

```bash
packer version
```

## 2. Configure Cloud Credentials

Packer must be allowed to create temporary VMs and images in each cloud.

### AWS

Install and configure the AWS CLI:

```bash
aws configure
```

Your IAM user or role needs permissions for EC2 image building, including creating and deleting temporary instances, volumes, snapshots, security groups, and AMIs.

### Azure

Create the resource group that will store the managed image:

```bash
az group create --name packer-images-rg --location eastus
```

Create a service principal:

```bash
az ad sp create-for-rbac --name packer-image-builder --role Contributor --scopes /subscriptions/<subscription-id>
```

Use the returned values in `variables.pkrvars.hcl`.

### Google Cloud

Set your active project and authenticate:

```bash
gcloud auth application-default login
gcloud config set project <project-id>
```

Enable Compute Engine API:

```bash
gcloud services enable compute.googleapis.com
```

Your account needs permission to create/delete temporary Compute Engine VMs and create images.

## 3. Create Your Variables File

Copy the example:

```bash
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
```

Edit `variables.pkrvars.hcl` and replace the placeholder values.

Do not commit `variables.pkrvars.hcl` if it contains real secrets.

## 4. Initialize Packer Plugins

From this `packer` directory:

```bash
packer init .
```

## 5. Validate The Template

```bash
packer validate -var-file=variables.pkrvars.hcl .
```

## 6. Build Images

Build all clouds:

```bash
packer build -var-file=variables.pkrvars.hcl .
```

Build only AWS:

```bash
packer build -only=amazon-ebs.ubuntu -var-file=variables.pkrvars.hcl .
```

Build only Azure:

```bash
packer build -only=azure-arm.ubuntu -var-file=variables.pkrvars.hcl .
```

Build only Google Cloud:

```bash
packer build -only=googlecompute.ubuntu -var-file=variables.pkrvars.hcl .
```

## Important Notes

- The current `bootstrap.sh` is written for Ubuntu/Debian because it uses `apt-get`.
- Packer creates a temporary VM, copies `bootstrap.sh` into it, runs it, turns the VM into an image, then deletes the temporary VM.
- Building images costs money because temporary cloud VMs, disks, snapshots, and images are created.
- Jenkins will already be installed in the image. When a VM is launched from the image, Jenkins should run on port `8080`.
- Open port `8080` in your cloud security rules only if you actually want to access Jenkins from outside the VM.
