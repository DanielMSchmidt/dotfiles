## Terraform

# Execute local terraform binary
alias tfl="/Users/dschmidt/work/hashicorp/terraform/bin/terraform"
# Build terraform binary
alias tfb="fish -c 'cd /Users/dschmidt/work/hashicorp/terraform && go build -ldflags=\"-X 'main.experimentsAllowed=yes'\" -v -o bin/'"
# Build terraform binary for linux
alias tfbl="fish -c 'cd /Users/dschmidt/work/hashicorp/terraform && GOOS=linux GOARCH=amd64 go build -ldflags=\"-X 'main.experimentsAllowed=yes'\" -v -o bin/'"
# Watch terraform binary build
alias tfw="fish -c 'cd /Users/dschmidt/work/hashicorp/terraform && gow -v -c build -v -ldflags=\"-X 'main.experimentsAllowed=yes'\" -o bin/'"

## Stacks

# Set my tf binary to the local one
set -x TFSTACKS_TERRAFORM_BINARY /Users/dschmidt/work/hashicorp/terraform/bin/terraform

# set debug level
set -x TFSTACKS_LOG_LEVEL trace

# Execute local tfstacks binary
alias scli="/Users/dschmidt/work/hashicorp/terraform-stacks-cli/dist/tfstacks"
# Build tfstacks binary
alias sclib="fish -c 'cd /Users/dschmidt/work/hashicorp/terraform-stacks-cli && make build'"

# Debug
alias dlvtfrpc="fish -c 'cd /Users/dschmidt/work/hashicorp/terraform && dlv attach (ps | grep 'terraform rpcapi' | head -1 | awk '{ print $1 }')'"

# Go-TFE tests against atlas
alias goTfeTests="ENABLE_BETA=1 OAUTH_CLIENT_GITHUB_TOKEN=$GITHUB_TOKEN TFE_ADDRESS="https://(atlas_hostname)" TFE_TOKEN=(atlas_token) go test ./... -v"
