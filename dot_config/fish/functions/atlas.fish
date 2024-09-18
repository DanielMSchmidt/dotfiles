set -x ATLAS_PATH $HOME/work/hashicorp/atlas
set -x AGENT_PATH $HOME/work/hashicorp/tfc-agent
set -x TERRAFORM_PATH $HOME/work/hashicorp/terraform
set -x TERRAFORM_CREDENTIALS_FILE $HOME/.terraform.d/credentials.tfrc.json

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
    cd $HOME/work/hashicorp/tfc-agent && LD_FLAGS="-X 'github.com/hashicorp/tfc-agent/core/components/stacks.terraformCliPath=/terraform/bin/terraform'" make docker && cd $CURRENT_DIR
end

function agent_run_docker -d "Runs the agent in docker"
    set JAEGER_RUNNING (docker ps --filter "name=jaeger" --format "{{.Names}}" | grep -w "jaeger" > /dev/null; echo $status)
    
    if test $JAEGER_RUNNING -ne 0
        docker run  -e TFC_AGENT_LOG_LEVEL=trace -e \
            TFC_AGENT_ACCEPT=plan,apply,stack_prepare,stack_plan,stack_apply \
            -e _TFC_AGENT_STACK_COMPONENTS_ENABLED=1 \
            -e TFC_AGENT_AUTO_UPDATE=disabled \
            -e TFC_AGENT_LOG_LEVEL=debug \
            -e TFC_AGENT_NAME="stack-agent-1" \
            -e TFC_ADDRESS="https://$(atlas_hostname)" \
            -e TFC_AGENT_TOKEN="$(agent_token)" \
            -e TFC_AGENT_OTLP_ADDRESS="jaeger:4317" \
            --link jaeger \
            -v $HOME/work/hashicorp/terraform:/terraform \
            hashicorp/tfc-agent:latest
        else
            docker run  -e TFC_AGENT_LOG_LEVEL=trace -e \
                TFC_AGENT_ACCEPT=plan,apply,stack_prepare,stack_plan,stack_apply \
                -e _TFC_AGENT_STACK_COMPONENTS_ENABLED=1 \
                -e TFC_AGENT_AUTO_UPDATE=disabled \
                -e TFC_AGENT_LOG_LEVEL=debug \
                -e TFC_AGENT_NAME="stack-agent-1" \
                -e TFC_ADDRESS="https://$(atlas_hostname)" \
                -e TFC_AGENT_TOKEN="$(agent_token)" \
                -v $HOME/work/hashicorp/terraform:/terraform \
                hashicorp/tfc-agent:latest
    end
    
end

function agent_build_and_run_docker -d "Builds and runs the agent"
    agent_build_docker && agent_run_docker
end

# Go-TFE tests against atlas
function goTfeTests -d "Run go-tfe integration tests"
    set TFE_ADDRESS "https://$(atlas_hostname)"
    set TFE_TOKEN (atlas_token)
    ENABLE_BETA=1 OAUTH_CLIENT_GITHUB_TOKEN=$GITHUB_TOKEN go test ./... -v
end

function atlas_rspec -d "Run atlas rspec tests"
    set CURRENT_DIR (pwd)
    
    cd $ATLAS_PATH && tfcdev stack console /usr/local/bundle/bin/bundle exec rspec $argv && cd $CURRENT_DIR
end

function jaeger_start -d "Starts Jaeger Tracing"
    docker run -d --rm --name jaeger \
      -e COLLECTOR_ZIPKIN_HOST_PORT=:9411 \
      -p 6831:6831/udp \
      -p 6832:6832/udp \
      -p 5778:5778 \
      -p 16686:16686 \
      -p 4317:4317 \
      -p 4318:4318 \
      -p 14250:14250 \
      -p 14268:14268 \
      -p 14269:14269 \
      -p 9411:9411 \
      -e COLLECTOR_OTLP_ENABLED=true \
      jaegertracing/all-in-one:1.61.0
end

function jaeger_open -d "Opens Jaeger UI"
    open "http://localhost:16686"
end

function jaeger_stop -d "Stops Jaeger"
    docker stop jaeger
end