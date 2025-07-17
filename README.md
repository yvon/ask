# ask

A simple CLI tool to interact with Claude AI via the Anthropic API.

## Beliefs

1. **One-shot prompting is more effective than conversations** - I find it better to craft a single, well-thought-out prompt and iterate on it if needed, rather than having back-and-forth conversations with the model.

2. **Full prompt control matters** - I want complete visibility and control over what's sent to the LLM, without agents hiding information or adding unnecessary complexity.

3. **Token efficiency is both practical and responsible** - LLMs consume significant energy, so minimizing token usage is not just cost-effective but also more environmentally conscious.

## Usage
```
Usage: ask [OPTIONS] [FILES...] [PROMPT...]

Question AI via various providers. Create and apply patches.

Arguments:
  FILES...     Input files to include in the prompt
  PROMPT...    Prompt text (can also be provided via stdin)

Options:
  --max-tokens <number>    Maximum tokens to generate (default: 5000)
  --temperature <float>    Sampling temperature 0.0-1.0 (default: 0.0)
  --prefill <text>         Text to prefill the assistant's response
  --system <text>          System message to set context
  --model <name>           Model to use (overrides environment variables)
  --diff                   Generate a git patch (equivalent to --prefill "diff --git")
  --apply                  Apply the generated patch (implies --diff)
  -h, --help               Show this help message

Environment Variables:
  PAGER                    Pager for output (default: less)

OpenAI Compatible Endpoint
  ASK_BASE_URL             Base URL for the API endpoint
  ASK_API_KEY              API key for authentication
  ASK_MODEL                Model name to use

Anthropic
  ANTHROPIC_API_KEY        API key for Anthropic
  ASK_MODEL                Model to use (default: claude-sonnet-4-20250514)

OpenAI
  OPENAI_API_KEY           API key for OpenAI
  ASK_MODEL                Model to use (default: gpt-4.1-2025-04-14)

Examples:
  ask "who created Zig language?"
  ask main.c "extract parsing to dedicated function"
  make 2>&1 | ask "why this error?"
  ask - < data
```

## Pager

STDOUT is piped to a pager. It defaults to `PAGER` environment variable or `less` if not set.  
Disable it by setting it to `PAGER=cat`.

My preference goes to `less -XE` (prevents clearing screen and quits if output fits on one screen).

---
Most of the code in this project has been written by hand. What was not has been carefully read and validated.
