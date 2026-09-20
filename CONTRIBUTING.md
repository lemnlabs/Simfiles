# Contributing to Simfiles

Thank you for your interest in contributing to Simfiles! We welcome all contributions, including bug reports, feature suggestions, documentation improvements, and pull requests.

---

## Issues & Discussions

- **Bug Reports**: Include clear steps to reproduce, expected vs. actual behavior, and your macOS/Xcode versions.
- **Feature Requests**: Describe the problem you are solving, the proposed solution, and how it benefits users.
- Open issues or start discussions via [GitHub Issues](https://github.com/lemnlabs/Simfiles/issues).

---

## Development & Contribution Workflow

1. Fork the repository and create a feature branch (`git checkout -b feat/my-new-feature`).
2. Make your changes and verify that the project builds cleanly.
3. Ensure all lint checks and formatting guidelines pass.
4. Commit your changes following the Conventional Commits specification.
5. Push to your branch and open a Pull Request.

---

## Commit Message Guidelines (Conventional Commits)

Commit messages must follow the Conventional Commits format in lowercase with an imperative mood:

`<type>(<scope>): <description>` or `<type>: <description>`

### Types
- `feat`: A new user-facing feature
- `fix`: A bug fix
- `refactor`: Code changes that neither fix a bug nor add a feature
- `chore`: Maintenance tasks, build configuration, or dependency updates
- `style`: Code style, whitespace, or formatting changes
- `test`: Adding or modifying tests
- `docs`: Documentation changes

### Examples
```bash
feat: add drag-and-drop file import to sandbox
fix(simulator): resolve data container path resolution for system apps
refactor: extract directory monitor synchronization
chore: update build settings for swift 6
```

---

## Pre-Commit Verification

Before submitting a pull request, ensure the following checks pass locally:

1. **Lint and Code Style**
   ```bash
   swift format lint -r Simfiles
   # To auto-format in-place:
   swift format format -i -r Simfiles
   ```

2. **Clean Build & Swift 6 Concurrency**
   Zero compiler errors and zero concurrency warnings (data-race safety, `@MainActor` isolation):
   ```bash
   xcodebuild build -scheme Simfiles -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
   ```

3. **Working Tree Cleanliness**
   Ensure no temporary files (e.g., `.DS_Store`, `*.xcuserdata`) are tracked:
   ```bash
   git status
   ```
