# Contributing

Thanks for helping improve this project. This repository maintains the GatewayCrate Docker image, powered by LiteLLM; changes that only affect multi-service orchestration belong in [self-hosted-ai-stack](https://github.com/hwdsl2/self-hosted-ai-stack).

## Before You Start

- Search existing issues and pull requests.
- Keep changes focused and easy to review.
- For upstream LiteLLM behavior, check the upstream project first.
- Do not include master keys, provider API keys, private prompts, logs with secrets, or credentials.

## Pull Requests

- Update `README.md`, env examples, or compose examples when behavior changes.
- Include the Docker image/tag, architecture, and provider path tested.
- For upstream version changes, link the upstream release, tag, or commit.

## Testing

Test the smallest relevant path before opening a PR, for example:

- Build or run the image when Dockerfile/runtime behavior changes.
- Exercise the proxy API, model registration, or helper script touched by the change.
- Check PostgreSQL-related behavior when changing persistence or virtual key support.
- Run ShellCheck when editing shell scripts.
