# Contributing to zkv.zig

Thank you for your interest in contributing to zkv.zig!

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/muhammad-fiaz/zkv.zig.git
   cd zkv.zig
   ```

2. Ensure you have Zig 0.16.0 or later installed:
   ```bash
   zig version
   ```

3. Build the library:
   ```bash
   zig build
   ```

4. Run tests:
   ```bash
   zig build test
   ```

5. Run tests with compression support:
   ```bash
   zig build -Dzstd test
   zig build -Dbrotli test
   ```

## Code Style

- Follow Zig 0.16.0 coding conventions
- No ASCII banner separators or decorative comment blocks
- Every public symbol must have a `///` doc comment
- Test blocks live at the bottom of each file
- Use the standard library wherever possible instead of reimplementing
- Never use `anyerror` in public signatures; use the defined Error set

## Submitting Changes

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Ensure all tests pass
5. Submit a pull request

## Testing

All public functions must have tests. Internal modules should also have tests for their core functionality.

Run the full test suite:
```bash
zig build test
```

## Documentation

Update documentation for any public API changes. Ensure all new public symbols have proper doc comments.
