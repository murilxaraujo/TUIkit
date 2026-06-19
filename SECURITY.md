# Security Policy

TUIkit is a terminal UI framework. Security reports should focus on vulnerabilities in the framework, project tooling, release artifacts, or generated templates.

## Supported versions

TUIkit is currently pre-1.0. The latest tagged release or release candidate is the supported line for security fixes unless release notes state otherwise.

## Reporting a vulnerability

Please do not disclose suspected vulnerabilities publicly before maintainers have had a chance to investigate.

Report security issues through GitHub private vulnerability reporting when available, or contact the maintainers privately with:

- affected version or commit;
- operating system and Swift version;
- reproduction steps or proof of concept;
- impact and any known mitigations.

## Scope

In scope:

- terminal escape handling issues caused by TUIkit;
- generated project-template behavior;
- release or documentation artifacts that could mislead users into unsafe setup;
- dependency or build-tool vulnerabilities introduced by this repository.

Out of scope:

- vulnerabilities in downstream applications using TUIkit;
- terminal emulator bugs not caused by TUIkit;
- social engineering or denial-of-service reports without a framework-specific issue.
