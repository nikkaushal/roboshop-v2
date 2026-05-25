ENV ?= prd

init:
	git pull
	rm -f .terraform/terraform.tfstate
	terraform init -backend-config=environments/$(ENV)/state.tfvars

plan:
	terraform init -backend-config=environments/$(ENV)/state.tfvars
	terraform plan -var-file=environments/$(ENV)/main.tfvars

apply:
	git pull
	rm -f .terraform/terraform.tfstate
	terraform init -backend-config=environments/$(ENV)/state.tfvars
	terraform apply -auto-approve -var-file=environments/$(ENV)/main.tfvars

destroy:
	git pull
	rm -f .terraform/terraform.tfstate
	terraform init -backend-config=environments/$(ENV)/state.tfvars
	terraform destroy -auto-approve -var-file=environments/$(ENV)/main.tfvars
