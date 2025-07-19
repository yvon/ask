# ask

A minimalist CLI tool to interact with LLMs.

```
Usage: ask [OPTIONS] [PROMPT...]

Arguments:
  PROMPT...    Prompt text (can also be provided via stdin)

Options:
  --max-tokens <number>    Maximum tokens to generate (default: 5000)
  --temperature <float>    Sampling temperature 0.0-1.0 (default: 0.0)
  --prefill <text>         Prefill the assistant's response
  --system <text>          System message to set context
  --model <name>           Model to use (overrides environment variables)
  -h, --help               Show this help message

Anthropic
  ANTHROPIC_API_KEY        API key for Anthropic
  ASK_MODEL                Default to claude-sonnet-4-20250514

OpenAI
  OPENAI_BASE_URL          Optionnal (e.g., https://openrouter.ai/api/v1)
  OPENAI_API_KEY           API key for OpenAI
  ASK_MODEL                Default to gpt-4.1-2025-04-14 when base url is not set

Examples:
  ask "who created Zig language?"
  ask "extract parsing to dedicated function" < main.c
  make 2>&1 | ask "why this error?"
```

## Minimalist

I removed a lot of features during the development of this tool, trying to embrace the Unix philosophy: minimalist and modular.

I initially allowed files to be passed as arguments. Those were added to the prompt with their filename as a prefix but that's what pipes are made for. You may use utilities like [bat](https://github.com/sharkdp/bat) to add extra formatting. I also don't want to impose a specific format.

I removed the automatic pager and the ability to generate and apply patches too.

For inspiration here is my current configuration via fish functions:

```fish
# -- Add files to prompt --
# f main.c | ask "extract parsing to dedicated function"
#
function f
  bat --style="header-filename,numbers" --color never 
end

# -- Pager --
# X is for no clear screen, E for automatic exit on last page
#
function ask
  command ask $argv | less -XE
end

# -- Generate patches --
# ask_patch "create new shell script printing hello world"
# git apply --reject --recount /tmp/patch
#
function ask_patch
  ask --system="Reply with a unified diff only" $argv | tee /tmp/patch
end
```

## Beliefs

1. I find it better to craft a single, well-thought-out prompt and iterate on it if needed, rather than having back-and-forth conversations with the model.

2. I want complete visibility and control over what's sent to the LLM.

3. LLMs consume significant energy, so minimizing token usage is not just cost-effective but also more environmentally conscious.

4. LLM patches are often flawed, and I prefer manual review and selective integration over automatic application. More broadly, I don't believe agents and automation represent the future of generative AI.
