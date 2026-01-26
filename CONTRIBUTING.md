# Contributing to Ace-Step Action

Thank you for your interest in contributing to Ace-Step Action! This document provides guidelines and instructions for contributing.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/acestep-action.git`
3. Create a new branch: `git checkout -b feature/your-feature-name`

## Development Setup

### Prerequisites

- Docker (for building and testing the action)
- Python 3.10+
- Git

### Local Development

1. Make your changes to the code
2. Test locally using Docker:
   ```bash
   docker build -t acestep-action .
   docker run -e INPUT_TEXT="Test message" acestep-action
   ```

3. Run Python syntax checks:
   ```bash
   python3 -m py_compile src/main.py
   ```

## Making Changes

### Code Style

- Follow PEP 8 style guidelines for Python code
- Use meaningful variable and function names
- Add docstrings to functions and classes
- Keep functions focused and concise

### Testing

- Test your changes locally before submitting
- Ensure the Docker image builds successfully
- Verify the action works with the test workflow

## Submitting Changes

1. Commit your changes with clear, descriptive commit messages
2. Push to your fork
3. Create a Pull Request with:
   - A clear title describing the change
   - A detailed description of what changed and why
   - Any relevant issue numbers

### Pull Request Guidelines

- Keep PRs focused on a single feature or fix
- Include tests if adding new functionality
- Update documentation as needed
- Ensure all checks pass

## Reporting Issues

When reporting issues, please include:

- A clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Your environment (OS, GitHub Actions runner, etc.)
- Relevant logs or error messages

## Questions?

Feel free to open an issue for questions or discussions about contributing.

## Code of Conduct

Be respectful and constructive in all interactions. We're all here to make this project better.
