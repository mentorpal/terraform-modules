# Contributing guidelines

1. Install dependencies

```zsh
brew install pre-commit terraform-docs
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

pre-commit hooks will check:

- validate terraform config
- check yaml formattings
- format terraform config
- fix missing `\n` at the end of files
- fix trailing whitespaces
