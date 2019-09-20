# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- None.

## [1.5.3] - 2019-09-20

### Changed

- Exclude two tables which already exist in a simpler form as properties, and
  other properties which exist on every table unnecessarily.

## [1.5.2] - 2019-08-30

### Fixed

- Syntax changes for DbData.
- Exclusions added for the current version of SMO.
- ForeignKeys are now checked on creation (should fix untrusted bug).

### Added

- Support for SQL 2017 temporal tables and on delete cascade.

## [1.5.1] - 2019-06-18

### Fixed

- Added aliases for constrained endpoint compatibility.

## [1.5.0] - 2019-04-17

### Changed

- Improve module load time.

### Fixed

- Changelog syntax passes VS Code markdown linter.

## [1.4.2] - 2018-10-30

### Changed

- Internal structure and documentation. Version bump for PowerShellGallery.
