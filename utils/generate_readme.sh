#!/bin/sh

set -e
cd $(dirname "$0")

cat <<EOF
# ask

A simple CLI tool to interact with LLMs via various APIs.

EOF
echo '```'
cat ../src/usage.txt
echo '```'

cat <<EOF

---

## Beliefs

1. I find it better to craft a single, well-thought-out prompt and iterate on it if needed, rather than having back-and-forth conversations with the model.

2. I want complete visibility and control over what's sent to the LLM.

3. LLMs consume significant energy, so minimizing token usage is not just cost-effective but also more environmentally conscious.

4. LLM patches are often flawed, and I prefer manual review and selective integration over automatic application. More broadly, I don't believe agents and automation represent the future of generative AI.
