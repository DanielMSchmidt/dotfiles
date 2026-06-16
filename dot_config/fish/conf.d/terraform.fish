## Terraform

# Set a default terraform path for my local terraform repo
set -x TERRAFORM_PATH_PRIVATE $HOME/work/hashicorp/terraform-private
set -x TERRAFORM_PATH $HOME/work/hashicorp/terraform

## Normal Builds
# Execute local terraform binary
function tfl -d "Run local terraform binary"
    echo "Using terraform binary at $TERRAFORM_PATH/bin/terraform"
    $TERRAFORM_PATH/bin/terraform $argv
end
# Build terraform binary
function tfb -d "Build local terraform binary"
    echo "Building terraform binary at $TERRAFORM_PATH/bin/terraform"
    fish -c "cd $TERRAFORM_PATH && mise x -- go build -ldflags=\"-X 'main.experimentsAllowed=yes'\" -v -o bin/"
end
# Build terraform binary for linux
function tfbl -d "Build local terraform binary for linux"
    fish -c "cd $TERRAFORM_PATH && GOOS=linux GOARCH=amd64 mise x -- go build -ldflags=\"-X 'main.experimentsAllowed=yes'\" -v -o bin/"
end
# Watch terraform binary build
function tfw -d "Watch local terraform binary build"
    fish -c "cd $TERRAFORM_PATH && gow -v -c build -v -ldflags=\"-X 'main.experimentsAllowed=yes'\" -o bin/"
end

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

## Terraform Policy Plugin

# Set a default path for my local terraform policy plugin repo
set -x TERRAFORM_POLICY_PLUGIN_PATH $HOME/work/hashicorp/terraform-policy-plugin

# Point the tfc-agent development override at the locally built (linux) policy
# plugin binary. `make bin-local-dev` in tfc-agent reads TFPOLICY_BINARY and
# links this binary into the agent instead of downloading the tfpolicy plugin
# release, so the agent uses the plugin from $TERRAFORM_POLICY_PLUGIN_PATH.
set -x TFPOLICY_BINARY $TERRAFORM_POLICY_PLUGIN_PATH/bin/tfpolicy-plugin

# Build terraform policy plugin binary (native OS, e.g. to run/test on this host)
function tpb -d "Build local terraform policy plugin binary"
    echo "Building terraform policy plugin binary at $TERRAFORM_POLICY_PLUGIN_PATH/bin/tfpolicy-plugin"
    fish -c "cd $TERRAFORM_POLICY_PLUGIN_PATH && mise x -- go build -v -o bin/tfpolicy-plugin"
end
# Build terraform policy plugin binary for linux (agent-friendly, used by tfc-agent)
function tpbl -d "Build local terraform policy plugin binary for linux"
    echo "Building linux terraform policy plugin binary at $TERRAFORM_POLICY_PLUGIN_PATH/bin/tfpolicy-plugin"
    fish -c "cd $TERRAFORM_POLICY_PLUGIN_PATH && GOOS=linux GOARCH=amd64 mise x -- go build -v -o bin/tfpolicy-plugin"
end
