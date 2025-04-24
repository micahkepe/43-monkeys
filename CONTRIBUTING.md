# Contributing to 43 Monkeys

Thank you for your interest in contributing to **43 Monkeys**, a 2D
rogue-like built with Godot Engine 4.4. This document outlines the process
for contributing code, assets, documentation, or ideas to the project. It is
intended to ensure consistency, maintain code quality, and streamline
collaboration.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Repository Setup](#repository-setup)
- [Contribution Workflow](#contribution-workflow)
- [Code Standards](#code-standards)
- [Asset Guidelines](#asset-guidelines)
- [Pull Request Review](#pull-request-review)
- [Licensing](#licensing)
- [Contact](#contact)

---

## Prerequisites

Before contributing, ensure you have the following tools installed:

- [Godot Engine 4.4](https://godotengine.org/download)
- Git and a GitHub account

We expect all contributors to be familiar with Git workflows and Godot
scene/nodes architecture. Refer to the [Godot
documentation](https://docs.godotengine.org/en/stable/) for technical guidance.

---

## Repository Setup

1. **Fork the repository** and clone your fork locally:

   ```bash
   git clone https://github.com/YOUR-USERNAME/43-monkeys.git
   cd 43-monkeys
   ```

2. **Open the project** in Godot:

   - Launch Godot Engine 4.4.
   - Click "Import Project", navigate to the cloned directory, and select the
     project.

3. **Build and run** the game to verify setup:
   - Click "Play" to confirm that the game launches without errors.

---

## Contribution Workflow

1. **Create a new branch** from `main` for your work:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**, following the code and asset guidelines outlined
   below.

3. **Test locally** using the Godot editor. Ensure new features do not break
   existing functionality.

4. **Push to your fork** and open a pull request:

   ```bash
   git push origin feature/your-feature-name
   ```

5. **Complete the pull request template** with a clear description of your
   changes, reasoning behind major decisions, and any known limitations or
   follow-up items.

---

## Code Standards

- Use **GDScript** unless a specific justification is made for using C++ or
  another language.
- Follow idiomatic Godot 4.4 GDScript conventions:
  - Snake_case for variables and functions.
  - PascalCase for class names.
- Maintain logical scene structure: prefer reusable scenes for repeatable
  units (e.g., enemies, interactables).
- Include comments where logic is non-obvious, especially AI, signal
  handling, or animation control.
- Keep functions small and composable. Avoid deeply nested control flow.
- Remove unused code or variables before submitting.

---

## Asset Guidelines

Contributors submitting graphical or audio assets should adhere to the
following:

- **Sprite resolution** should match existing game assets (typically 16x16 or
  32x32 pixel base tiles).
- Use **lossless formats** (e.g., PNG for images, WAV or Ogg for audio).
- Avoid including copyrighted or unlicensed content.
- Animations must be packed into sprite sheets with consistent frame
  dimensions and frame count documentation.
- Audio should be normalized and loopable if intended for background music.

If you are unsure whether your asset fits stylistically, open an issue first
with a preview.

---

## Pull Request Review

All pull requests are subject to technical review. Reviewers will check:

- Code correctness and compatibility with the current Godot project
- Adherence to style and structure guidelines
- Reasonable asset inclusion and organization
- Testing sufficiency for new features or changes
- Potential issues across supported platforms (Web, Windows, macOS, Linux)

Pull requests must be approved by at least one maintainer before merging. You
may be asked to revise your PR to address comments or resolve merge conflicts.

---

## Licensing

By submitting a pull request or pushing to this repository, you agree that
your contributions are licensed under the terms of the [GPL-3.0
License](./LICENSE). Do not contribute code or assets you do not have the
right to relicense under GPL-3.0.

---

## Contact

For major changes or coordination, please start a [GitHub Issue](../../issues)
or [Discussion](../../discussions).
