# Contributing to MLOps Infrastructure

We're excited that you're interested in contributing to our MLOps infrastructure project! This document provides guidelines for contributing to the project.

## Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, please include:

- A clear and descriptive title
- Steps to reproduce the issue
- Expected vs actual behavior
- Environment information (Kubernetes version, Helm version, etc.)
- Screenshots or logs if applicable

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- A clear and descriptive title
- Detailed description of the proposed feature
- Use cases and benefits
- Implementation considerations

### Development Process

1. **Fork the repository** and create your branch from `main`
2. **Make your changes** following the coding standards
3. **Test your changes** thoroughly
4. **Update documentation** as needed
5. **Submit a pull request**

### Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/MLOpsInfrastructure.git
   cd MLOpsInfrastructure
   ```

2. Set up pre-commit hooks:
   ```bash
   pip install pre-commit
   pre-commit install
   ```

3. Validate your setup:
   ```bash
   ./scripts/validate-setup.sh
   ```

### Coding Standards

#### Python Code
- Follow PEP 8 style guidelines
- Use Black for code formatting
- Use isort for import sorting
- Write docstrings for all functions and classes
- Include type hints where appropriate

#### YAML Files
- Use 2 spaces for indentation
- Follow yamllint rules (see `.yamllint` config)
- Use descriptive names for resources
- Include comments for complex configurations

#### Ansible
- Use descriptive task names
- Include tags for logical grouping
- Use variables for configurable values
- Follow Ansible best practices

#### Kubernetes Manifests
- Use proper resource limits and requests
- Include health checks (liveness and readiness probes)
- Use ConfigMaps and Secrets appropriately
- Follow Kubernetes naming conventions

### Testing

All contributions should include appropriate tests:

#### Infrastructure Tests
- Validate YAML syntax
- Test Kubernetes manifest validity
- Verify Helm chart templating
- Test Ansible playbook syntax

#### Python Tests
- Unit tests for all functions
- Integration tests for workflows
- Coverage should be maintained above 80%

#### Manual Testing
- Test deployment in a staging environment
- Verify all components are healthy
- Test the demo workflows

### Documentation

Please update documentation when:
- Adding new features
- Changing existing functionality
- Fixing bugs that were due to unclear documentation

Documentation should be:
- Clear and concise
- Include examples
- Follow the existing structure
- Updated in both README and relevant docs/ files

### Pull Request Process

1. **Create a descriptive PR title** following the format: `type(scope): description`
2. **Fill out the PR template** completely
3. **Link related issues** using GitHub keywords
4. **Ensure all checks pass** before requesting review
5. **Respond to feedback** promptly
6. **Squash commits** if requested

### Branch Naming

Use the following naming convention for branches:
- `feature/description` - for new features
- `bugfix/description` - for bug fixes
- `hotfix/description` - for urgent fixes
- `docs/description` - for documentation updates

### Commit Messages

Follow conventional commits format:
- `feat: add new feature`
- `fix: resolve issue with component`
- `docs: update documentation`
- `style: format code`
- `refactor: improve code structure`
- `test: add or update tests`
- `chore: update dependencies`

### Release Process

Releases are created automatically when tags are pushed:
1. Update version in relevant files
2. Create a tag: `git tag -a v1.0.0 -m "Release version 1.0.0"`
3. Push the tag: `git push origin v1.0.0`

## Component-Specific Guidelines

### Kafka
- Follow Kafka best practices for topic configuration
- Use proper partitioning strategies
- Configure appropriate retention policies

### Spark
- Optimize resource allocation
- Use appropriate data formats (Parquet, Delta)
- Follow Spark coding best practices

### Airflow
- Write idempotent DAGs
- Use proper task dependencies
- Include proper error handling

### MLflow
- Follow MLflow tracking best practices
- Use proper experiment organization
- Document model requirements

### Observability
- Include proper metrics and logging
- Use appropriate alert thresholds
- Follow monitoring best practices

## Getting Help

If you need help:
1. Check the documentation in the `docs/` directory
2. Search existing issues and discussions
3. Create a new issue with the "question" label
4. Reach out to the maintainers

## Recognition

Contributors will be recognized in the project's README and release notes.

Thank you for contributing to the MLOps Infrastructure project!
