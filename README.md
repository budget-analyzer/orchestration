# Budget Analyzer

A production-grade microservices financial management system built as an open-source learning resource for architects exploring AI-assisted development.

## Quick Start

See **[Getting Started](docs/development/getting-started.md)** for complete setup instructions including prerequisites.

```bash
git clone https://github.com/budgetanalyzer/orchestration.git
cd orchestration
./setup.sh   # Will tell you if prerequisites are missing
tilt up
```

Open https://app.budgetanalyzer.localhost

## Documentation

- [Getting Started](docs/development/getting-started.md)
- [Architecture Overview](docs/architecture/system-overview.md)
- [Development Guide](CLAUDE.md)

## Service Repositories

- [service-common](https://github.com/budgetanalyzer/service-common) - Shared library
- [transaction-service](https://github.com/budgetanalyzer/transaction-service) - Transaction API
- [currency-service](https://github.com/budgetanalyzer/currency-service) - Currency API
- [budget-analyzer-web](https://github.com/budgetanalyzer/budget-analyzer-web) - React frontend
- [session-gateway](https://github.com/budgetanalyzer/session-gateway) - Authentication BFF
- [token-validation-service](https://github.com/budgetanalyzer/token-validation-service) - JWT validation
- [permission-service](https://github.com/budgetanalyzer/permission-service) - Permissions API

## License

MIT
