#!/bin/sh

set -e
cd $(dirname "$0")

cat <<EOF
# ask

A simple CLI tool to interact with Claude AI via the Anthropic API.

Based on a few core beliefs about working effectively with LLMs:

1. **One-shot prompting is more effective than conversations** - I find it better to craft a single, well-thought-out prompt and iterate on it if needed, rather than having back-and-forth conversations with the model.

2. **Full prompt control matters** - I want complete visibility and control over what's sent to the LLM, without agents hiding information or adding unnecessary complexity.

3. **Token efficiency is both practical and responsible** - LLMs consume significant energy, so minimizing token usage is not just cost-effective but also more environmentally conscious.

4. **Simple tools over autonomous agents** - I don't believe that giving LLMs more autonomy necessarily makes them more intelligent or helpful. Direct, controlled interaction tends to produce better results.

I wanted something simpler than aider.chat or Claude code. The goal is to have:
- Full control over prompts without unnecessary overhead
- Minimal token usage
- A lightweight CLI for quick questions with or without files

## Usage
EOF
echo '```'
cat usage.txt
echo '```'
