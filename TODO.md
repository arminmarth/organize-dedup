# TODO - Future Development

This document tracks planned improvements, enhancements, and known issues for future releases.

**Current Version:** v2.0.2 (Production Ready ✅)

---

## 🎯 v2.0.3 - Polish & Documentation

**Priority:** Medium  
**Target:** Minor release with documentation improvements and polish

### Documentation Improvements

- [ ] **Update README version badge** from v2.0.1 to v2.0.2
- [ ] **Add ShellCheck badge** to README for instant quality confidence
- [ ] **Add "Known Behaviors" section** to README covering:
  - Duplicate handling in `mv` mode (duplicates left in source directory)
  - Long filenames with SHA512 (up to 160 characters)
  - Persistent dedup registry across runs
  - Bash 4.2+ requirement
  - No-arg run behavior (requires explicit options)
  - Optional archive extraction tools

### Code Quality

- [ ] **Set executable bit in git**
  ```bash
  git update-index --chmod=+x organize_and_dedup.sh
  ```
- [ ] **Run ShellCheck** and address any warnings
- [ ] **Add inline comments** for complex logic sections

---

## 🚀 v2.1.0 - Feature Enhancements

**Priority:** Medium  
**Target:** Minor release with new features

### User Experience Improvements

- [ ] **Add progress bar** for long operations
  - Show percentage complete
  - Estimated time remaining
  - Files processed / total files

- [ ] **Add dry-run mode** (`--dry-run`)
  - Show what would be done without making changes
  - Useful for testing organization schemes

- [ ] **Add interactive mode** (`--interactive`)
  - Prompt before processing each file
  - Allow skip/rename/custom actions

- [ ] **Add summary report** option
  - Generate HTML report of processed files
  - Include statistics and visualizations
  - Export to JSON/CSV

### Performance Improvements

- [ ] **Parallel processing** for hash calculation
  - Use GNU parallel or xargs -P
  - Configurable thread count
  - Significant speedup for large datasets

- [ ] **Incremental hashing** for large files
  - Hash only first N MB for quick duplicate detection
  - Full hash only when needed

- [ ] **Cache file metadata** to avoid repeated stat calls

### Organization Features

- [ ] **Custom organization patterns**
  - User-defined directory structures
  - Template variables (e.g., `{year}/{month}/{category}`)
  - Regex-based categorization rules

- [ ] **Smart duplicate handling**
  - Keep highest quality version (resolution, bitrate)
  - Configurable preference rules
  - Option to create symlinks instead of skipping

- [ ] **Metadata preservation**
  - Copy file timestamps
  - Preserve extended attributes
  - Option to embed hash in EXIF/metadata

---

## 🔧 v2.2.0 - Advanced Features

**Priority:** Low  
**Target:** Minor release with advanced capabilities

### Archive Handling

- [ ] **Nested archive extraction**
  - Extract archives within archives
  - Configurable depth limit
  - Handle circular references

- [ ] **Selective extraction**
  - Extract only specific file types
  - Filter by size, date, name pattern

- [ ] **Archive creation**
  - Option to re-archive organized files
  - Configurable compression levels

### Integration Features

- [ ] **Database backend** option
  - SQLite for hash registry
  - Query capabilities
  - Better performance for large registries

- [ ] **Cloud storage support**
  - rclone integration
  - Direct upload to S3, Google Drive, etc.
  - Sync mode for backups

- [ ] **Web UI**
  - Browser-based interface
  - Real-time progress monitoring
  - Configuration management

### Deduplication Enhancements

- [ ] **Perceptual hashing** for images/videos
  - Detect similar (not just identical) files
  - Configurable similarity threshold
  - Integration with pHash or similar

- [ ] **Content-aware deduplication**
  - Ignore metadata differences
  - Compare actual content only
  - Useful for photos with different EXIF

---

## 🐛 Known Issues / Limitations

**Priority:** Track for future resolution

### Current Limitations

- [ ] **No Windows native support**
  - Requires WSL or Cygwin
  - Consider PowerShell port or native Windows version

- [ ] **Large file handling**
  - Memory usage grows with file count
  - Consider streaming approach for very large files

- [ ] **Network filesystem issues**
  - Hardlinks don't work across network mounts
  - Add detection and warning

- [ ] **Filename encoding**
  - May have issues with non-UTF8 filenames
  - Test and improve international character support

### Edge Cases

- [ ] **Circular symlinks** in recursive mode
  - Currently may cause infinite loops
  - Add detection and handling

- [ ] **Sparse files**
  - Hash calculation may be slow
  - Consider special handling

- [ ] **Very long paths**
  - May exceed PATH_MAX on some systems
  - Add detection and graceful failure

---

## 📚 Documentation Tasks

### User Documentation

- [ ] **Create wiki** on GitHub
  - Detailed usage examples
  - Common workflows
  - Troubleshooting guide

- [ ] **Add video tutorials**
  - Basic usage
  - Advanced features
  - Docker deployment

- [ ] **Create FAQ** section
  - Common questions
  - Best practices
  - Performance tips

### Developer Documentation

- [ ] **Add CONTRIBUTING.md**
  - Code style guide
  - Testing requirements
  - Pull request process

- [ ] **Add architecture documentation**
  - Code organization
  - Function flow diagrams
  - Extension points

- [ ] **Create test suite**
  - Unit tests for functions
  - Integration tests for workflows
  - Performance benchmarks

---

## 🧪 Testing & Quality Assurance

### Test Coverage

- [ ] **Automated testing framework**
  - BATS (Bash Automated Testing System)
  - CI/CD integration with GitHub Actions
  - Test matrix for different OS/versions

- [ ] **Edge case testing**
  - Empty directories
  - Permission errors
  - Disk full scenarios
  - Interrupted operations

- [ ] **Performance testing**
  - Benchmark with various file counts
  - Memory profiling
  - Identify bottlenecks

### Compatibility Testing

- [ ] **Test on multiple platforms**
  - Ubuntu 20.04, 22.04, 24.04
  - Debian 11, 12
  - macOS (Intel and Apple Silicon)
  - Alpine Linux (for Docker)

- [ ] **Test with various shells**
  - Bash 4.2, 4.4, 5.0, 5.1, 5.2
  - Zsh compatibility
  - Dash/sh compatibility (if feasible)

---

## 🔐 Security & Reliability

### Security Enhancements

- [ ] **Input validation hardening**
  - Sanitize all user inputs
  - Prevent path traversal attacks
  - Validate hash algorithm names

- [ ] **Secure temporary files**
  - Use mktemp properly
  - Set restrictive permissions
  - Clean up on exit/error

- [ ] **Audit logging**
  - Log all operations
  - Include timestamps and user info
  - Optional syslog integration

### Reliability Improvements

- [ ] **Atomic operations**
  - Use temp files + rename for safety
  - Prevent partial writes
  - Transaction-like behavior

- [ ] **Crash recovery**
  - Save state periodically
  - Resume interrupted operations
  - Rollback on failure

- [ ] **Verification mode**
  - Verify hashes after copy/move
  - Detect corruption
  - Automated integrity checks

---

## 📦 Distribution & Packaging

### Package Management

- [ ] **Create Debian package** (.deb)
- [ ] **Create RPM package** (.rpm)
- [ ] **Submit to Homebrew** (macOS)
- [ ] **Submit to AUR** (Arch Linux)
- [ ] **Create snap package**
- [ ] **Create flatpak**

### Docker Improvements

- [ ] **Multi-stage builds** for smaller images
- [ ] **Alpine-based image** for minimal size
- [ ] **Docker Compose** examples
- [ ] **Kubernetes deployment** examples

---

## 🎨 User Interface

### CLI Improvements

- [ ] **Color output** with --color option
- [ ] **Better error messages** with suggestions
- [ ] **Autocomplete** for bash/zsh
- [ ] **Man page** generation

### Alternative Interfaces

- [ ] **TUI (Text User Interface)**
  - Using dialog or whiptail
  - Interactive configuration
  - Real-time monitoring

- [ ] **REST API**
  - Control via HTTP
  - Integration with other tools
  - Remote operation

---

## 📊 Analytics & Monitoring

### Statistics

- [ ] **Detailed statistics tracking**
  - Space saved by deduplication
  - Processing speed metrics
  - File type distribution

- [ ] **History tracking**
  - Keep log of all runs
  - Trend analysis
  - Rollback capabilities

### Monitoring

- [ ] **Prometheus metrics** export
- [ ] **Health check endpoint** for Docker
- [ ] **Notification system**
  - Email on completion
  - Webhook integration
  - Slack/Discord notifications

---

## 🌐 Community & Ecosystem

### Community Building

- [ ] **Create discussion forum** (GitHub Discussions)
- [ ] **Set up issue templates**
  - Bug report template
  - Feature request template
  - Question template

- [ ] **Create project roadmap**
  - Public visibility
  - Community voting on features
  - Regular updates

### Ecosystem Integration

- [ ] **Integration with file managers**
  - Nautilus script
  - Thunar custom action
  - macOS Finder service

- [ ] **Plugin system**
  - Custom categorization rules
  - Custom hash algorithms
  - Custom output formats

---

## 📅 Release Planning

### v2.0.3 (Next Release)
**Target:** 1-2 weeks  
**Focus:** Documentation polish and minor fixes

### v2.1.0
**Target:** 1-2 months  
**Focus:** User experience and performance

### v2.2.0
**Target:** 3-4 months  
**Focus:** Advanced features and integrations

### v3.0.0
**Target:** 6-12 months  
**Focus:** Major architecture improvements, breaking changes if needed

---

## 🤝 Contributing

If you'd like to contribute to any of these items:

1. Check if there's already an issue for it
2. Comment on the issue or create a new one
3. Fork the repository
4. Create a feature branch
5. Submit a pull request

See CONTRIBUTING.md (to be created) for detailed guidelines.

---

## 📝 Notes

- Items marked with ☐ are not started
- Items marked with ✅ are completed
- Priority levels: High (next release), Medium (future release), Low (nice to have)
- This is a living document - suggestions welcome!

**Last Updated:** 2025-12-02  
**Maintainer:** @arminmarth
