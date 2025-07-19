#!/bin/sh

set -e
cd $(dirname "$0")

cat <<EOF
# ask

A minimalist CLI tool to interact with LLMs.

\`\`\`
$(cat ../src/usage.txt)
\`\`\`

## Some beliefs

- I find it better to craft a single, well-thought-out prompt and iterate on it if needed, rather than having back-and-forth conversations with the model.

- I want complete visibility and control over what's sent to the LLM.

- LLMs consume significant energy, so minimizing token usage is not just cost-effective but also more environmentally conscious.

- LLM patches are often flawed, and I prefer manual review and selective integration over automatic application. More broadly, I don't believe agents and automation represent the future of generative AI.

## History

I removed many features during development, embracing the Unix philosophy of building minimalist, modular tools that do one thing well.

File handling: I initially allowed files as arguments, automatically prefixing them with filenames in the prompt. But that's what pipes are for—and I don't want to impose a specific format. You can use utilities like [bat](https://github.com/sharkdp/bat) for advanced formatting.

Output: I removed the automatic pager. Different users prefer different pagers (or none at all), and it's trivial to pipe the output yourself.

Patch generation: LLMs are inconsistent and sloppy: the optimal approach varies too much.


An example of Bash functions:

\`\`\`bash
f() {
    bat --style="header-filename,numbers" --color never "\$@"
}

ask() {
    command ask "\$@" | less -XE
}

# f main.c | ask "extract parsing to dedicated function"
\`\`\`
