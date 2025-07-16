#!/bin/sh

set -e
cd $(dirname "$0")

cat <<EOF
# ask

A simple CLI tool to interact with Claude AI via the Anthropic API.

## Beliefs

1. **One-shot prompting is more effective than conversations** - I find it better to craft a single, well-thought-out prompt and iterate on it if needed, rather than having back-and-forth conversations with the model.

2. **Full prompt control matters** - I want complete visibility and control over what's sent to the LLM, without agents hiding information or adding unnecessary complexity.

3. **Token efficiency is both practical and responsible** - LLMs consume significant energy, so minimizing token usage is not just cost-effective but also more environmentally conscious.

## Usage
EOF
echo '```'
cat ../src/usage.txt
echo '```'

cat <<EOF

---

Most of the code in this project has been written by hand. What was not has been carefully read and validated.
