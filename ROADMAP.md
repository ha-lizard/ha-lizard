# HA-Lizard Project Roadmap and Versioning Strategy

## Versioning Strategy

- **Version 2.4.0**: The current stable version of the project.

- **Version 2.4.X**: Future bug fixes and minor improvements will be made under the `2.4.X` series. These versions will primarily focus on addressing bugs and patching issues identified in version 2.4.0.

- **Version 2.5.X**: The `2.5.X` series will include significant changes. These versions will bring structural improvements and major changes to the project's architecture, workflows, or other planned enhancements without introducing new features.

- **Version 2.6.X**: The `2.6.X` series will introduce new features (yet to be defined). These features will add new functionalities and extend the capabilities of the project. The exact scope of these features will be defined closer to the release date.

---

## Roadmap of Tasks Version 2.5.X

### Restructure of Files/Directory Structure Following the Linux File System Hierarchy

- **Objective**: Improve the organization of the repository to align with Linux's standard filesystem structure.
- **Tasks**:
  - Analyze the current file structure.
  - Reorganize files and directories based on common Linux filesystem standards (e.g., `/etc`, `/var`, `/usr`).
  - Refactor `rpm` packaging to comply with these conventions.

### Lint the Shell Scripts Using Tools Like ShellCheck

- **Objective**: Ensure the shell scripts are free of common syntax and logic errors, improving code quality and maintainability.
- **Tasks**:
  - Run `shellcheck` on all shell scripts in the repository.
  - Address any warnings or errors flagged by `shellcheck`.
  - Implement continuous linting checks in the CI/CD pipeline.

### Lint and Improve the RPM Packaging

- **Objective**: Refactor and improve the `rpm` packaging for better compliance, stability, and functionality.
- **Tasks**:
  - Review and improve the spec file.
  - Address any issues or inconsistencies in the current packaging.

### Improve/Create Documentation and Man Pages

- **Objective**: Ensure the project has clear, up-to-date documentation for users and developers.
- **Tasks**:
  - Review the current documentation files (`README.md`, `INSTALL`, `COPYING`, etc.).
  - Create or improve man pages for key scripts and configuration files.
  - Add additional usage examples and troubleshooting sections.
  - Generate PDF auto-documentation.

### Trigger RPM Repository GitHub Action on Release

- **Objective**: Automate the process of building and pushing RPMs when a new release is tagged on GitHub.
- **Tasks**:
  - Set up a GitHub Action that triggers on release creation.
  - Configure the action to build and deploy RPM packages to a designated repository.
  - Ensure proper version tagging and release notes are included in the process.

### Migrate Init Scripts to `systemd`

- **Objective**: Modernize the project's init scripts by migrating them to `systemd` for better service management.
- **Tasks**:
  - Review the current init scripts.
  - Implement corresponding `systemd` service files.
  - Ensure that all scripts are compatible with `systemd` for automatic startup and shutdown.

## Roadmap of Tasks Version 2.6.X

### Check and Improve Fencing Mechanism

- **Objective**: Ensure the fencing mechanisms work correctly and reliably, preventing split-brain scenarios.
- **Tasks**:
  - Review the current fencing implementation.
  - Identify any issues or areas for improvement.
  - Test and implement fixes as needed, ensuring support for different fencing methods (e.g., IPMI, DRAC, etc.).

### Create Tests for Shell Scripts

- **Objective**: Increase test coverage and reliability by creating unit tests for shell scripts.
- **Tasks**:
  - Identify key scripts that require testing.
  - Write unit tests using tools like `shunit2` or `bats`.
  - Integrate tests into the CI pipeline to ensure continuous testing and validation.

### Create Auto Install of RPMs and Validations

- **Objective**: Automate the installation process of RPM packages on test environments and ensure they are correctly validated.
- **Tasks**:
  - Set up automated deployment pipelines for RPM packages.
  - Add post-deployment validation checks to confirm that the package has been correctly installed and is functioning.
  - Integrate with CI/CD tools like GitHub Actions or Jenkins.

### Add New Monitoring and Alerting (e.g., Telegram, Nagios)

- **Objective**: Enhance the project's monitoring and alerting capabilities with popular tools like Telegram and Nagios.
- **Tasks**:
  - Implement integration with Telegram for alerts and notifications.
  - Create or improve integration with Nagios for system monitoring.
  - Ensure customizable thresholds and alerting behaviors.

---

## Notes

- This roadmap outlines the key objectives and tasks for future releases and improvements. Each task can be broken down into further subtasks based on specific needs.
- The release strategy ensures that bug fixes are handled in the `2.4.X` versions, while major improvements are planned for `2.5.X`. Future features and enhancements will be implemented in `2.6.X`.
