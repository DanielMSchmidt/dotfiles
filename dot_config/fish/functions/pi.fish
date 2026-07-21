function pi -d "Start Pi with fresh Doormat Bedrock credentials"
    if not command -q doormat
        echo "Error: doormat is not installed."
        return 1
    end

    doormat login -f; or return

    if not lsof -nP -iTCP:9000 -sTCP:LISTEN >/dev/null 2>&1
        command doormat cred-server >/tmp/doormat-cred-server.log 2>&1 &
        for _ in (seq 1 20)
            if lsof -nP -iTCP:9000 -sTCP:LISTEN >/dev/null 2>&1
                break
            end
            sleep 0.1
        end
    end

    if not lsof -nP -iTCP:9000 -sTCP:LISTEN >/dev/null 2>&1
        echo "Error: Doormat credential server did not start; see /tmp/doormat-cred-server.log"
        return 1
    end

    set -lx AWS_PROFILE frontiers_dev_bedrock
    set -lx AWS_REGION us-east-1
    set -lx BEDROCK_MANTLE_AWS_PROFILE frontiers_dev_bedrock
    command pi $argv
end
