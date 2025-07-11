# ask

A simple CLI tool to interact with Claude AI via the Anthropic API.

I wanted something simpler than aider.chat or Claude code. The goal is to have:
- Full control over prompts without unnecessary overhead
- Minimal token usage
- A lightweight CLI for quick questions with or without files

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
  -h, --help               Show this help message

Environment Variables:
  ANTHROPIC_API_KEY        Required API key for Anthropic

Examples:
  ask "Why do people like Zig?"
  ask main.c "Explain this code"
  echo "Hello world" | ask "Translate to Spanish"
  ask --temperature 0.7 --max-tokens 1000 "Write a poem"
  make 2>&1 | ask "Why this error?"
```

## Response handling

The complete response is saved as `ask.response` in your system's temp directory.

**Important**: If the LLM response contains diff blocks, they will be automatically applied to files in the current directory. Git usage is highly recommended to track and review changes before they are applied.
