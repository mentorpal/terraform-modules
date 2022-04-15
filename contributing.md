# Contributing guidelines

Before committing your changes, make sure to have necessary tools installed in order for automatic code formatting
and docs generation to work. Pre-commits are based on https://github.com/antonbabenko/pre-commit-terraform

Steps to take (only first time)

1. Install dependencies

```zsh
brew install pre-commit gawk terraform-docs
```

2. Install the git hook scripts

run pre-commit install to set up the git hook scripts

```zsh
pre-commit install
```

3. [optional] Test pre-commit hooks

```zsh
pre-commit run -a
```

4. Done

Next time you commit, pre-commit hooks will trigger to check:

- format terraform config
- validate terraform config
- generate readmes for modules
- check yaml formattings
- fix trailing whitespaces
- fix missing `\n` at the end of files
