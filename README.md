# AOS Packages

> **⚠️ Archive Notice**: This repository is archived and no longer maintained. It is provided as-is for reference and educational purposes.

A collection of packages for process development on the [AO computer](https://ao.ar.io/). These packages provide reusable functionality for building AO processes, including ownership management, access control, and subscription capabilities.

## ⚠️ Maintenance Status

**This repository is archived and will not receive updates, bug fixes, or security patches.** Use at your own risk. If you find issues or need features, you may fork this repository and maintain your own version.

## Origin

This project was initially developed by [Autonomous Research](https://autonomous.finance/).

## Packages

This repository contains three main packages:

### [`ownable`](./packages/ownable/)
Simple process ownership and access control for AO processes. Provides functionality to manage single-owner processes and gate access to handlers based on ownership.

**Features:**
- Native process ownership management
- Ownership transfer and renouncement
- Access control modifiers (`onlyOwner`, `onlyOwnerOrSelf`)

### [`ownable-multi`](./packages/ownable-multi/)
Multi-owner process ownership and access control for AO processes. Extends the `ownable` package to support multiple equal owners.

**Features:**
- Shared ownership management with multiple owners
- Add/remove owners functionality
- Access control for multi-owner scenarios

### [`subscribable`](./packages/subscribable/)
Subscription provider capabilities for AO processes. Enables processes to register subscribers and dispatch notifications for topic-related events.

**Features:**
- Subscriber registration and management
- Topic-based event notifications
- Payment-based subscription activation
- Two storage backends: vanilla (Lua tables) and DB (SQLite)

## Installation

Each package can be installed via APM (AO Package Manager) or downloaded locally. See individual package READMEs for detailed installation and usage instructions.

### Via APM

```lua
APM.install('@autonomousfinance/ownable')
APM.install('@autonomousfinance/ownable-multi')
APM.install('@autonomousfinance/subscribable')
```

### Local Installation

Use `apm-tool` to download packages locally:

```bash
npm i -g apm-tool
apm download @autonomousfinance/ownable
```

## Security Considerations

⚠️ **Important**: Before using these packages in production:

1. **Review all code** - These packages are provided as-is without maintenance
2. **Test thoroughly** - Ensure packages work correctly with your use case
3. **Payment tokens** - The `subscribable` package includes a default test payment token. **You must configure your own payment token** before using in production
4. **Access control** - Understand the ownership and access control mechanisms before deploying
5. **Process IDs** - Some packages reference external process IDs (e.g., renounce manager). Verify these are still valid and trustworthy

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

As this repository is archived, contributions will not be accepted. If you wish to improve these packages, please fork the repository and maintain your own version.