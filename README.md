# ask

A simple CLI tool to interact with Claude AI via the Anthropic API.

## Beliefs

1. **One-shot prompting is more effective than conversations** - I find it better to craft a single, well-thought-out prompt and iterate on it if needed, rather than having back-and-forth conversations with the model.

2. **Full prompt control matters** - I want complete visibility and control over what's sent to the LLM, without agents hiding information or adding unnecessary complexity.

3. **Token efficiency is both practical and responsible** - LLMs consume significant energy, so minimizing token usage is not just cost-effective but also more environmentally conscious.

## Usage
```
Usage: ask [OPTIONS] [FILES...] [PROMPT...]

Ask questions to Claude AI via the Anthropic API.

Arguments:
  FILES...     Input files to include in the prompt
  PROMPT...    Prompt text (can also be provided via stdin)

Options:
  --max-tokens <number>    Maximum tokens to generate (default: 5000)
  --temperature <float>    Sampling temperature 0.0-1.0 (default: 0.0)
  --prefill <text>         Text to prefill the assistant's response
  --system <text>          System message to set context
  --model <name>           Model to use (default: claude-sonnet-4-20250514)
  -                        Force interactive mode (prompt from terminal)
  -h, --help               Show this help message

Environment Variables:
  ANTHROPIC_API_KEY        Required API key for Anthropic
  PAGER                    Pager for output (default: less, set to 'cat' to disable)

Examples:
  ask "Why do people like Zig?"
  ask main.c "Comment the main function"
  echo "Hello world" | ask "Translate to Spanish"
  ask --temperature 0.7 --max-tokens 1000 "Write a poem"
  make 2>&1 | ask "Why this error?"
  ask - < data
```
