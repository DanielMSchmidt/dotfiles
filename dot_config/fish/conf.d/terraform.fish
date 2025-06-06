## Terraform

# Set a default terraform path for my local terraform repo
set -x TERRAFORM_PATH_PRIVATE $HOME/work/hashicorp/terraform-private
set -x TERRAFORM_PATH $HOME/work/hashicorp/terraform

## Normal Builds
# Execute local terraform binary
alias tfl="$TERRAFORM_PATH/bin/terraform"
# Build terraform binary
alias tfb="fish -c 'cd $TERRAFORM_PATH && mise x -- go build -ldflags=\"-X 'main.experimentsAllowed=yes'\" -v -o bin/'"
# Build terraform binary for linux
alias tfbl="fish -c 'cd $TERRAFORM_PATH && GOOS=linux GOARCH=amd64 mise x -- go build -ldflags=\"-X 'main.experimentsAllowed=yes'\" -v -o bin/'"
# Watch terraform binary build
alias tfw="fish -c 'cd $TERRAFORM_PATH && gow -v -c build -v -ldflags=\"-X 'main.experimentsAllowed=yes'\" -o bin/'"

## Private Builds
# Execute local terraform binary
alias tflp="$TERRAFORM_PATH_PRIVATE/bin/terraform"
# Build terraform binary
alias tfbp="fish -c 'cd $TERRAFORM_PATH_PRIVATE && mise x -- go build -ldflags=\"-X 'main.experimentsAllowed=yes'\" -v -o bin/'"
# Build terraform binary for linux
alias tfblp="fish -c 'cd $TERRAFORM_PATH_PRIVATE && GOOS=linux GOARCH=amd64 mise x -- go build -ldflags=\"-X 'main.experimentsAllowed=yes'\" -v -o bin/'"
# Watch terraform binary build
alias tfwp="fish -c 'cd $TERRAFORM_PATH_PRIVATE && gow -v -c build -v -ldflags=\"-X 'main.experimentsAllowed=yes'\" -o bin/'"

## Stacks

# Set my tf binary to the local one
set -x TFSTACKS_TERRAFORM_BINARY $TERRAFORM_PATH/bin/terraform

# set debug level
set -x TFSTACKS_LOG_LEVEL trace

# Execute local tfstacks binary
alias scli="$HOME/work/hashicorp/terraform-stacks-cli/dist/tfstacks"
# Build tfstacks binary
alias sclib="fish -c 'cd $HOME/work/hashicorp/terraform-stacks-cli && make build'"

# Debug
alias dlvtfrpc="fish -c 'cd $TERRAFORM_PATH && dlv attach (ps | grep 'terraform rpcapi' | head -1 | awk '{ print $1 }')'"
