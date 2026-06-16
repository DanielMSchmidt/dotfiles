set -x ATLAS_PATH $HOME/work/hashicorp/atlas
set -x AGENT_PATH $HOME/work/hashicorp/tfc-agent
set -x TERRAFORM_PATH $HOME/work/hashicorp/terraform
set -x TERRAFORM_CREDENTIALS_FILE $HOME/.terraform.d/credentials.tfrc.json

set -x _TFC_AGENT_STACK_COMPONENTS_ENABLED 1

set -x ATLAS_ORG_NAME hashicorp

# Name of the agent pool to use. Override by exporting ATLAS_AGENT_POOL_NAME.
if not set -q ATLAS_AGENT_POOL_NAME
    set -gx ATLAS_AGENT_POOL_NAME dschmidt-ap
end

function atlas_hostname -d "Outputs the atlas host name"
    if set -q ATLAS_HOSTNAME
        echo $ATLAS_HOSTNAME
    else
        set CURRENT_DIR (pwd)
        echo (cd "$ATLAS_PATH" && eval "$(tfcdev stack env --export 2> /dev/null)"  && echo "$TFE_FQDN" && cd $CURRENT_DIR)
    end
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

function agent_pool_id -d "Gets the id of the \$ATLAS_AGENT_POOL_NAME agent pool, creating it if missing"
    set TOKEN (atlas_token)
    set HOST (atlas_hostname)

    set POOL_ID (curl \
            --header "Authorization: Bearer $TOKEN" \
            --header "Content-Type: application/vnd.api+json" \
            --request GET \
            https://$HOST/api/v2/organizations/$ATLAS_ORG_NAME/agent-pools  2> /dev/null \
        | jq -r --arg name "$ATLAS_AGENT_POOL_NAME" 'first(.data[] | select(.attributes.name == $name) | .id) // empty')

    if test -z "$POOL_ID"
        echo "Agent pool '$ATLAS_AGENT_POOL_NAME' not found, creating it..." >&2
        set POOL_ID (curl \
                --header "Authorization: Bearer $TOKEN" \
                --header "Content-Type: application/vnd.api+json" \
                --request POST \
                --data "{\"data\":{\"type\":\"agent-pools\",\"attributes\":{\"name\":\"$ATLAS_AGENT_POOL_NAME\"}}}" \
                https://$HOST/api/v2/organizations/$ATLAS_ORG_NAME/agent-pools 2> /dev/null \
            | jq -r '.data.id // empty')
    end

    if test -z "$POOL_ID"
        echo "ERROR: Could not find or create agent pool '$ATLAS_AGENT_POOL_NAME'" >&2
        return 1
    end

    echo $POOL_ID
end

function agent_token -d "Gets agent token from atlas"
    set TOKEN (atlas_token)
    set HOST (atlas_hostname)

    set AGENT_POOL_ID (agent_pool_id)
    or return 1

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
    cd $HOME/work/hashicorp/tfc-agent && LD_FLAGS="-X 'github.com/hashicorp/tfc-agent/internal/development.terraformCliPath=/terraform/bin/terraform' -X 'github.com/hashicorp/tfc-agent/internal/development.tfpolicyPluginPath=/tfpolicy/bin/tfpolicy-plugin'" make docker && cd $CURRENT_DIR
end

# Port Jaeger exposes for OTLP/gRPC on the host (see jaeger_start).
set -x JAEGER_OTLP_PORT 4317

# Host ports for the OpenTelemetry Collector that sits in front of Jaeger and
# Prometheus. The agent sends all OTLP signals here; the collector fans traces
# out to Jaeger and exposes metrics for Prometheus to scrape.
set -x OTEL_COLLECTOR_OTLP_PORT 4319
set -x OTEL_COLLECTOR_PROM_PORT 8889
set -x PROMETHEUS_PORT 9090

# Shared Docker network so the agent, collector, Jaeger and Prometheus can talk
# to each other by container name (avoids the flaky host.docker.internal hop).
set -x OTEL_NETWORK tfc-otel

function _otel_network_ensure -d "Creates the shared OTel docker network if it doesn't exist yet"
    docker network inspect $OTEL_NETWORK >/dev/null 2>&1; or docker network create $OTEL_NETWORK >/dev/null
end

function jaeger_reachable -d "Returns success if Jaeger's OTLP port is reachable on the host"
    nc -z localhost $JAEGER_OTLP_PORT 2>/dev/null
end

function otel_collector_reachable -d "Returns success if the OTel collector's OTLP port is reachable on the host"
    nc -z localhost $OTEL_COLLECTOR_OTLP_PORT 2>/dev/null
end

function _agent_run_docker -d "Internal: runs the tfc-agent container; pass an OTLP address as \$argv[1] to enable tracing"
    set -l otel_args
    if test (count $argv) -gt 0; and test -n "$argv[1]"
        # Join the shared network so the agent can reach the collector by name.
        set otel_args \
            -e TFC_AGENT_OTLP_ADDRESS="$argv[1]" \
            --network $OTEL_NETWORK
    end

    # Forward TF_LOG from the host only when it's actually set, so we don't
    # pass an empty value into the container.
    set -l tf_log_args
    if set -q TF_LOG; and test -n "$TF_LOG"
        set tf_log_args -e TF_LOG="$TF_LOG"
    end

    docker run --rm \
        -e TFC_AGENT_ACCEPT=plan,apply,stack_prepare,stack_plan,stack_apply \
        -e _TFC_AGENT_STACK_COMPONENTS_ENABLED=1 \
        -e TFC_AGENT_AUTO_UPDATE=disabled \
        -e TFC_AGENT_LOG_LEVEL=trace \
        -e TFC_AGENT_NAME="stack-agent-1" \
        -e TFC_ADDRESS="https://$(atlas_hostname)" \
        -e TFC_AGENT_TOKEN="$(agent_token)" \
        $otel_args \
        $tf_log_args \
        -v $HOME/work/hashicorp/terraform:/terraform \
        -v $HOME/work/hashicorp/terraform-policy-plugin:/tfpolicy \
        hashicorp/tfc-agent:latest
end

function agent_run_docker -d "Runs the agent in docker (no tracing)"
    _agent_run_docker
end

function agent_run_docker_otel -d "Runs the agent in docker with OTel tracing + metrics via the collector"
    if not otel_collector_reachable
        echo "ERROR: OTel collector is not reachable on localhost:$OTEL_COLLECTOR_OTLP_PORT." >&2
        echo "Start the observability stack first with 'otel_stack_start'" >&2
        echo "(Jaeger UI: 'jaeger_open', Prometheus UI: 'prometheus_open'), then re-run this command." >&2
        return 1
    end
    # The agent joins $OTEL_NETWORK and reaches the collector by container name.
    _agent_run_docker "otel-collector:4317"
end

function agent_build_and_run_docker -d "Builds and runs the agent (no tracing)"
    agent_build_docker && agent_run_docker
end

function agent_build_and_run_docker_otel -d "Builds and runs the agent with Jaeger OTel tracing"
    agent_build_docker && agent_run_docker_otel
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
    _otel_network_ensure
    docker run -d --rm --name jaeger \
      --network $OTEL_NETWORK \
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

function otel_collector_start -d "Starts the OpenTelemetry Collector (traces -> Jaeger, metrics -> Prometheus)"
    _otel_network_ensure
    docker run -d --rm --name otel-collector \
        --network $OTEL_NETWORK \
        -p $OTEL_COLLECTOR_OTLP_PORT:4317 \
        -p $OTEL_COLLECTOR_PROM_PORT:8889 \
        -v $HOME/.config/otel-collector/config.yaml:/etc/otelcol-contrib/config.yaml \
        otel/opentelemetry-collector-contrib:0.154.0
end

function otel_collector_stop -d "Stops the OpenTelemetry Collector"
    docker stop otel-collector
end

function prometheus_start -d "Starts Prometheus (scrapes the collector's metrics)"
    _otel_network_ensure
    docker run -d --rm --name prometheus \
        --network $OTEL_NETWORK \
        -p $PROMETHEUS_PORT:9090 \
        -v $HOME/.config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
        prom/prometheus:v3.0.1
end

function prometheus_stop -d "Stops Prometheus"
    docker stop prometheus
end

function prometheus_open -d "Opens Prometheus UI"
    open "http://localhost:$PROMETHEUS_PORT"
end

function otel_stack_start -d "Starts Jaeger + OTel Collector + Prometheus"
    jaeger_start
    otel_collector_start
    prometheus_start
end

function otel_stack_stop -d "Stops Prometheus + OTel Collector + Jaeger"
    prometheus_stop
    otel_collector_stop
    jaeger_stop
end

function otel_stack_open -d "Opens the Jaeger and Prometheus UIs"
    jaeger_open
    prometheus_open
end

function otel_stack_status -d "Checks whether the OTel observability stack is operational"
    set -l all_ok 0
    set -l checks \
        "Jaeger (UI)|16686" \
        "Jaeger (OTLP)|$JAEGER_OTLP_PORT" \
        "OTel Collector (OTLP)|$OTEL_COLLECTOR_OTLP_PORT" \
        "OTel Collector (metrics)|$OTEL_COLLECTOR_PROM_PORT" \
        "Prometheus (UI)|$PROMETHEUS_PORT"

    for check in $checks
        set -l parts (string split "|" $check)
        set -l name $parts[1]
        set -l port $parts[2]
        if nc -z localhost $port 2>/dev/null
            printf "  \u2713 %-26s localhost:%s\n" $name $port
        else
            printf "  \u2717 %-26s localhost:%s (down)\n" $name $port
            set all_ok 1
        end
    end

    if test $all_ok -eq 0
        echo "OTel stack is operational."
    else
        echo "OTel stack is NOT fully operational. Start it with 'otel_stack_start'."
    end
    return $all_ok
end