# Contributing to ha-lizard

Thank you for your interest in contributing to ha-lizard! By contributing to this project, you help improve and extend it. Please follow these guidelines to ensure a smooth collaboration.

## Getting Started

To get started with the development environment, we use [Devbox](https://www.jetify.com/devbox), which simplifies the setup of the project for development and testing.

## Setting Up the Development Environment

**Clone the repository:**

```bash
git clone https://github.com/ha-lizard/ha-lizard.git
cd ha-lizard
```

**Install Devbox:**

If you don't have Devbox installed, follow the installation instructions [here](https://www.jetify.com/docs/devbox/installing_devbox/).

```bash
curl -fsSL https://get.jetify.com/devbox | bash
```

**Initialize the environment:**

Devbox will automatically set up the required environment based on the `devbox.json` and `devbox.lock` files.

```bash
devbox shell
```

This will prepare the container with all the dependencies required to contribute to the project.

## Code Style

We follow the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) for shell scripting and [PEP 8](https://peps.python.org/pep-0008/) for Python development. Please ensure your code adheres to these style guidelines.

- **Shell scripts**: Follow the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) with 2 spaces for indentation and no tabs.

- **Python scripts**: Follow [PEP 8](https://peps.python.org/pep-0008/), using 4 spaces for indentation and a maximum line length of 79 characters.

### Key Points

- Use 2 spaces for shell scripts (Google Shell Style Guide).

- Use 4 spaces for Python code (PEP 8).

- End all files with a newline.

- Avoid trailing whitespace.

- Function and variable names should be in lowercase, with words separated by underscores (e.g., `my_function`).

- Use `[[` for condition tests in shell scripts instead of `[`, and always quote variables (e.g., `"$@"`).

## Pre-Commit Hooks

We use [pre-commit hooks](https://pre-commit.com/) to ensure code quality before committing changes. These hooks will automatically check for common errors like trailing whitespace, code formatting, and other potential issues.

## Making Changes

**Create a feature branch:**

```bash
git checkout -b feature-branch
```

**Make your changes:**

- Follow the coding guidelines mentioned above.
- Add tests for your changes if applicable.

- Keep commit messages concise and descriptive (e.g., "Add feature X", "Fix bug in Y").

**Commit your changes:**

```bash
git add .
git commit -m "Description of the change"
```

**Push your changes:**

```bash
git push origin feature-branch
```

**Create a Pull Request (PR):**

1. Go to the repository on GitHub.
1. Click on "Compare & pull request."
1. Describe the changes you made and submit the PR.

## Code Reviews

After submitting a PR, the maintainers will review your changes. Be sure to address any comments and make necessary updates to your PR.

## License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project. See the LICENSE file for more information.

## Running Tests (TODO)
