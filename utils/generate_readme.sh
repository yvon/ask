#!/bin/sh

set -e
cd $(dirname "$0")

cat <<EOF
# ask

A minimalist CLI tool to interact with LLMs.

\`\`\`
$(cat ../src/usage.txt)
\`\`\`

## Minimalist

I removed a lot of features during the development of this tool, trying to embrace the Unix philosophy: minimalist and modular.

I initially allowed files to be passed as arguments. Those were added to the prompt with their filename as a prefix but that's what pipes are made for. You may use utilities like [bat](https://github.com/sharkdp/bat) to add extra formatting. I also don't want to impose a specific format.

I removed the automatic pager and the ability to generate and apply patches too.

For inspiration here is my current configuration via fish functions:

\`\`\`fish
# -- Add files to prompt --
# f main.c | ask "extract parsing to dedicated function"
#
function f
  bat --style="header-filename,numbers" --color never $argv
end

# -- Pager --
# X is for no clear screen, E for automatic exit on last page
#
function ask
  command ask \$argv | less -XE
end

# -- Generate patches --
# ask_patch "create new shell script printing hello world"
# git apply --reject --recount /tmp/patch
#
function ask_patch
  ask --system="Reply with a unified diff only" \$argv | tee /tmp/patch
end
\`\`\`

## Beliefs

1. I find it better to craft a single, well-thought-out prompt and iterate on it if needed, rather than having back-and-forth conversations with the model.

2. I want complete visibility and control over what's sent to the LLM.

3. LLMs consume significant energy, so minimizing token usage is not just cost-effective but also more environmentally conscious.

4. LLM patches are often flawed, and I prefer manual review and selective integration over automatic application. More broadly, I don't believe agents and automation represent the future of generative AI.
