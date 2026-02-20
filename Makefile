# SpaceWarp Makefile

.PHONY: all build test lint lint-fix clean install-deps run

# Default target
all: build

# Build the project
build:
	swift build

# Run tests
test:
	swift test

# Run SwiftLint
lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

# Auto-fix SwiftLint issues
lint-fix:
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint --fix --format; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build
	rm -rf build
	rm -rf DerivedData

# Install dependencies
install-deps:
	swift package resolve

# Run the app (for development)
run:
	swift run SpaceWarp

# Generate Xcode project (optional)
xcode:
	swift package generate-xcodeproj

# Install SwiftLint (macOS)
install-swiftlint:
	brew install swiftlint

# Build release version
release:
	swift build -c release

# Check for security issues
security-check:
	@echo "Checking for security issues..."
	@! grep -r "print(" SpaceWarp --include="*.swift" || echo "Warning: print statements found"
	@! grep -r "force_cast" SpaceWarp --include="*.swift" || echo "Warning: force casts found"

# Format code
format:
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat SpaceWarp; \
	else \
		echo "SwiftFormat not installed. Install with: brew install swiftformat"; \
	fi

# Development setup
setup: install-deps install-swiftlint
	@echo "Development environment ready!"
	@echo "Run 'make build' to build the project"
	@echo "Run 'make run' to run the app"
