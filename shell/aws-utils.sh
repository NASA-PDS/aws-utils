#!/usr/bin/env bash
# aws-utils.sh — AWS credential and access helpers for PDS engineers.
#
# Source this file from your shell rc, e.g. in ~/.bashrc:
#
#   source /path/to/aws-utils/shell/aws-utils.sh
#
# These are shell FUNCTIONS, not standalone scripts on PATH, because
# aws-creds-export needs to `eval` into your CURRENT shell's environment —
# a subprocess can only ever change its own environment, never its
# parent's. All four are kept together here so there's a single line to
# add to your rc file.
#
# Commands:
#   aws-creds-import                     Paste/stdin an AWS console credentials
#                                         block into ~/.aws/credentials
#   aws-creds-export <profile>           Eval a profile's resolved credentials
#                                         into the current shell
#   aws-sso-login <profile>              aws sso login --profile <profile>
#   aws-ssm-connect <target> <profile>   aws ssm start-session --target <target>
#                                         --profile <profile>

aws-creds-import() {
    local creds_file="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
    local input

    # Read from stdin if piped, otherwise pull from clipboard
    if [ -t 0 ]; then
        input="$(pbpaste)"
    else
        input="$(cat)"
    fi

    if [ -z "$input" ]; then
        echo "Error: no input provided (clipboard is empty and no stdin)" >&2
        return 1
    fi

    local profile key_id secret token
    profile=$(echo "$input" | grep -E '^\[.+\]'           | head -1 | tr -d '[]')
    key_id=$(echo "$input"  | grep -E 'aws_access_key_id' | head -1 | awk -F'=' '{print $2}' | tr -d ' ')
    secret=$(echo "$input"  | grep -E 'aws_secret_access' | head -1 | awk -F'=' '{print $2}' | tr -d ' ')
    token=$(echo "$input"   | grep -E 'aws_session_token' | head -1 | awk -F'=' '{print $2}' | tr -d ' ')

    if [ -z "$profile" ] || [ -z "$key_id" ] || [ -z "$secret" ]; then
        echo "Error: could not parse profile name, key ID, or secret from input" >&2
        return 1
    fi

    mkdir -p "$(dirname "$creds_file")"
    touch "$creds_file"

    # Remove any existing block for this profile, then append the fresh one
    local tmpfile
    tmpfile=$(mktemp)
    awk -v prof="[$profile]" '
      /^\[/ { in_block = ($0 == prof) }
      !in_block { print }
    ' "$creds_file" > "$tmpfile"
    mv "$tmpfile" "$creds_file"

    {
        echo "[$profile]"
        echo "aws_access_key_id=$key_id"
        echo "aws_secret_access_key=$secret"
        [ -n "$token" ] && echo "aws_session_token=$token"
    } >> "$creds_file"

    echo "Updated profile [$profile] in $creds_file"
}

aws-creds-export() {
    if [ -z "$1" ]; then
        echo "Usage: aws-creds-export <profile>" >&2
        return 1
    fi
    local cmd
    cmd=$(aws configure export-credentials --profile "$1" --format env) || return $?
    echo "$cmd"
    eval "$cmd"
}

aws-sso-login() {
    if [ -z "$1" ]; then
        echo "Usage: aws-sso-login <profile>" >&2
        return 1
    fi
    aws sso login --profile "$1"
}

aws-ssm-connect() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: aws-ssm-connect <target> <profile>" >&2
        return 1
    fi
    aws ssm start-session --target "$1" --profile "$2"
}
