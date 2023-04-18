#!/bin/bash
set -euo pipefail

usage()
{
    echo >&2 "$0 - disable Bamboo agent(s) via server rest API"
    echo >&2 ''
    echo >&2 "Usage: $0 [-p <host_pattern>] [-u <bamboo_user>] <bamboo_url>"
    echo >&2 ''
    echo >&2 'Options:'
    echo >&2 "  -p <host_pattern> -- grep pattern to match (default: '$(hostname)')"
    echo >&2 '  -u <bamboo_user> -- name of bamboo user (default: "bamboo")'
    echo >&2 ''
    echo >&2 'Positional Parameter:'
    echo >&2 '  <bamboo_url> url to a bamboo server, including scheme:// prefix'

    [ "$@" ] && exit "$@" || exit 2
}

bamboo_user='bamboo'
host_pattern="$(hostname)"

while getopts 'hp:u:' o
do
    case "$o" in
    h)
        usage 0
        ;;
    p)
        [ "$OPTARG" ] || usage
        host_pattern="$OPTARG"
        ;;
    u)
        [ "$OPTARG" ] || usage
        bamboo_user="$OPTARG"
        ;;
    *)
        usage
        ;;
    esac
done
shift $((OPTIND-1))

set +u
[ "$#" -eq 1 ] || usage
bamboo_url="$1"
if [ ! "$BAMBOO_PASSWORD" ]
then
    echo >&2 'please set the BAMBOO_PASSWORD environment variable'
    exit 1
fi
set -u

remote_agents=$(
	curl -X GET -su "${bamboo_user}:${BAMBOO_PASSWORD}" \
	"${bamboo_url}/rest/api/latest/agent/remote" \
	| jq -r '.[] | .name|=gsub(" "; "_") | [.id, .name] | join("%")'
)

declare -a target_agent_ids=()

for line in $(echo "$remote_agents" | grep "$host_pattern")
do
	agent_id="$(echo "$line" | cut -d% -f 1)"
	agent_name="$(echo "$line" | cut -d% -f 2)"
	echo "Agent '${agent_name}' matches (id '${agent_id}')"
	target_agent_ids+=("${agent_id}")
done

if [ ${#target_agent_ids[@]} -eq 0 ]
then
	echo "No matching agents found."
	exit 0
fi

echo "About to disable ${#target_agent_ids[@]} remote agents"

for agent_id in "${target_agent_ids[@]}"
do
	curl -H 'Accept: application/json' -X PUT -su "${bamboo_user}:${BAMBOO_PASSWORD}" \
	"${bamboo_url}/rest/api/latest/agent/${agent_id}/disable" | jq -M .
done

echo 'Done'
