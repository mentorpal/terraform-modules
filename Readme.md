# Content

This repository contains Terraform modules.

All modules have their description in their directory.

## How to setup pre-commit hooks
Follow the documentation at https://github.com/antonbabenko/pre-commit-terraform and https://pre-commit.com/

Run once:

```bash
# Install dependencies
brew install pre-commit terraform-docs
pre-commit install

# test pre-commit hooks
pre-commit run -a
```

pre-commit hooks:

- validate terraform config
- check yaml formattings
- format terraform config
- fix missing `\n` at the end of files
- fix trailing whitespaces
