set -x ATLAS_PATH /Users/dschmidt/work/hashicorp/atlas
set -x AGENT_PATH /Users/dschmidt/work/hashicorp/tfc-agent
set -x TERRAFORM_PATH /Users/dschmidt/work/hashicorp/terraform
set -x TERRAFORM_CREDENTIALS_FILE /Users/dschmidt/.terraform.d/credentials.tfrc.json

set -x _TFC_AGENT_STACK_COMPONENTS_ENABLED 1

function atlas_hostname -d "Outputs the atlas host name"
    set CURRENT_DIR (pwd)
    echo (cd "$ATLAS_PATH" && eval "$(tfcdev stack env --export 2> /dev/null)"  && echo "$TFE_FQDN" && cd $CURRENT_DIR)
end

function atlas_token -d "Get auth token to authenticate against atlas"
    set HOSTNAME (atlas_hostname)
    # Read the token from the file
    set TOKEN (jq -r ".credentials[\"$HOSTNAME\"].token" < "$TERRAFORM_CREDENTIALS_FILE")

    if test -z $TOKEN
        echo "ERROR: Token for '$HOSTNAME' is empty. Please run 'terraform login $HOSTNAME' to set the token."
        return 1
    end

    echo $TOKEN
end

function agent_token -d "Gets agent token from atlas"
    set TOKEN (atlas_token)
    set HOST (atlas_hostname)

    set AGENT_POOL_ID (curl \
            --header "Authorization: Bearer $TOKEN" \
            --header "Content-Type: application/vnd.api+json" \
            --request GET \
            https://$HOST/api/v2/organizations/hashicorp/agent-pools  2> /dev/null \
        | jq -r '.data[0].id')

    echo (curl \
            --header "Authorization: Bearer $TOKEN" \
            --header "Content-Type: application/vnd.api+json"  \
            --request POST \
            --data '{"data":{"type": "authentication-tokens", "attributes": {"description": "auto-generated"}}}' \
            https://$HOST/api/v2/agent-pools/$AGENT_POOL_ID/authentication-tokens 2> /dev/null \
        | jq -r .data.attributes.token)
end

function atlas_open -d "Opens atlas UI"
    open "https://$(atlas_hostname)"
end

function atlas_logs -d "Watches atlas logs"
    set CURRENT_DIR (pwd)
    cd $ATLAS_PATH && tfcdev stack logs atlas && cd $CURRENT_DIR
end

function agent_build -d "Builds the agent"
    set CURRENT_DIR (pwd)
    cd $AGENT_PATH && LD_FLAGS="-X 'core.components.stacks.terraformCliPath=$TERRAFORM_PATH'" make bin && cd $CURRENT_DIR
end

function agent_run -d "Runs the agent"
    $AGENT_PATH/bin/tfc-agent -name stack-agent-1 -log-level trace -accept plan,apply,stack_prepare,stack_plan,stack_apply -auto-update disabled -token (agent_token) -address https://(atlas_hostname)
end

function agent_build_and_run -d "Builds and runs the agent"
    agent_build && agent_run
end

function agent_build_docker -d "Builds the agent docker container"
    set CURRENT_DIR (pwd)
    cd /Users/dschmidt/work/hashicorp/tfc-agent && LD_FLAGS="-X 'github.com/hashicorp/tfc-agent/core/components/stacks.terraformCliPath=/terraform/bin/terraform'" make docker && cd $CURRENT_DIR
end

function agent_run_docker -d "Runs the agent in docker"
    docker run  -e TFC_AGENT_LOG_LEVEL=trace -e \
        TFC_AGENT_ACCEPT=plan,apply,stack_prepare,stack_plan,stack_apply \
        -e _TFC_AGENT_STACK_COMPONENTS_ENABLED=1 \
        -e TFC_AGENT_AUTO_UPDATE=disabled \
        -e TFC_AGENT_LOG_LEVEL=debug \
        -e TFC_AGENT_NAME="stack-agent-1" \
        -e TFC_ADDRESS="https://$(atlas_hostname)" \
        -e TFC_AGENT_TOKEN="$(agent_token)" \
        -v /Users/dschmidt/work/hashicorp/terraform:/terraform \
        hashicorp/tfc-agent:latest
end

function agent_build_and_run_docker -d "Builds and runs the agent"
    agent_build_docker && agent_run_docker
end
