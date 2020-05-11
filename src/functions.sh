function handler()
{
    local EVENT_DATA="$1"

    # The event.body data is still in escaped JSON string
    # So we need to parse the JSON twice
    local WORDS=$( echo "${EVENT_DATA}" | parse_json '["body"]' | parse_json '["words"]' )

    # VAR=(VAR) is syntax to convert to array
    local RESPONSE=( $(echo "$WORDS" | wc ) )

    printf '{
    "lines": %s,
    "words": %s,
    "characters": %s
}' ${RESPONSE[0]} ${RESPONSE[1]} ${RESPONSE[2]} | tr -d "[:space:]"
    return 0
}

function parse_json()
{
    # 1. Parse JSON from STDIN
    # 2. Optional - filter the value by args
    #
    # Example
    # Print all keys: echo '{"name": "Rio Astamal", "Age": 32}'
    # Print name: echo '{"name": "Rio Astamal", "Age": 32}' | parse_json '["name"]'
    python3 -c "import sys, json; print(json.load(sys.stdin)$@)"
}