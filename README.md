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

```bash
f() {
    bat --style="header-filename,numbers" --color never "$@"
}

ask() {
    command ask "$@" | less -XE
}

# f main.c | ask "extract parsing to dedicated function"
```
