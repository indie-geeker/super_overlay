# Security Policy

## Supported Versions

Security fixes are provided for the latest version published on pub.dev. The
unreleased `main` branch is reviewed while preparing the next release, but it
is not a supported distribution. Older release lines may receive a fix only
when the maintainer determines that backporting is practical.

## Reporting A Vulnerability

Do not open a public issue or discussion for a suspected vulnerability. Use
GitHub's private vulnerability-reporting form instead:

[Report a vulnerability privately](https://github.com/indie-geeker/super_overlay/security/advisories/new)

Only the repository maintainer and explicitly invited collaborators can access
the report while it is private. If GitHub does not show the reporting form,
make sure you are signed in before retrying the link.

Include enough information to reproduce and assess the issue:

- affected `super_overlay` version or commit;
- Flutter and Dart versions and target platform;
- affected API or overlay surface;
- minimal reproduction or proof of concept;
- expected and actual behavior;
- potential impact and any known mitigations.

Do not include secrets or personal data that are unnecessary to reproduce the
issue.

## Best-Effort Response Targets

This project is maintained independently. The following are targets, not a
service-level agreement:

- acknowledge a complete report within 7 calendar days;
- provide an initial assessment or request more information within 14 calendar
  days;
- coordinate remediation and disclosure timing according to severity,
  exploitability, and maintainer availability.

Reports may be closed when they cannot be reproduced, are outside the package's
documented support boundaries, or describe expected behavior without a
security impact. The maintainer will explain that decision in the private
advisory.

## Coordinated Disclosure

Please keep vulnerability details private until a fix or mitigation is
available and coordinated disclosure has been agreed. When appropriate, the
maintainer will publish a GitHub security advisory, credit the reporter with
their consent, and reference the fixed release.

Use the public [issue tracker](https://github.com/indie-geeker/super_overlay/issues)
for ordinary bugs, feature requests, and documentation problems that do not
contain security-sensitive details.
