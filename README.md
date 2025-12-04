# Lunaris Security Workshop

A demonstration repository showcasing security best practices and tools throughout the Software Development Lifecycle (SDLC). This project features a simple pizza shop application built with vanilla JavaScript (frontend) and ASP.NET Core Web API (.NET 10) (backend), designed to illustrate various security scanning and analysis techniques.

## 🎯 Purpose

This repository serves as a hands-on workshop for learning and implementing security measures in modern web application development. It intentionally includes security vulnerabilities and outdated dependencies to demonstrate how various security tools can detect and help remediate these issues.

## 🏗️ Application Architecture

- **Frontend**: Vanilla JavaScript application for browsing pizzas, managing a shopping basket, and creating orders
- **Backend**: ASP.NET Core Web API (.NET 10) providing pizza catalog and order management endpoints
- **Features**:
  - Browse pizza menu (data from API)
  - Add items to basket
  - Create orders (demonstration purposes)

## 🔒 Security Tools & Practices

### 1. Secret Scanning

**Tool**: GitLeaks  
**Script**: `gitleaks.ps1`  
**Purpose**: Scans the repository for accidentally committed secrets, API keys, passwords, and other sensitive information. The script uses the GitLeaks Docker image to perform the scan.

```powershell
.\gitleaks.ps1
```

### 2. Software Bill of Materials (SBOM) & Vulnerability Management

**Tools**: CycloneDX, Dependency-Track  
**Scripts**:

- `scripts\generateSbom.ps1` - Generates SBOM in CycloneDX format via the CycloneDX .NET CLI tool.
- `scripts\runDependencyTrack.ps1` - Runs Dependency-Track for vulnerability analysis via Docker.
- `docker-compose.dependency-track.yml` - Docker compose for Dependency-Track setup

**Purpose**: Creates a comprehensive inventory of all dependencies and identifies known vulnerabilities and license compliance issues.

```powershell
.\scripts\generateSbom.ps1
.\scripts\runDependencyTrack.ps1
```

SBOM files are located in the `sbom/` directory.

### 3. Static Code Analysis

**.NET Analyzers** are configured in the project to detect security issues such as:

- SQL injection vulnerabilities
- Other security anti-patterns

Check the WebApi project configuration for analyzer settings.

### 4. Dependency Vulnerability Scanning

**Tool**: .NET CLI  
**Command**:

```powershell
dotnet list package --vulnerable
```

**Purpose**: Identifies vulnerable NuGet packages in the solution. This repository intentionally includes outdated SQL packages with known vulnerabilities for demonstration purposes.

### 5. Dynamic Application Security Testing (DAST)

**Tool**: OWASP ZAP  
**Script**: `scripts\runOwaspZap.ps1`  
**Purpose**: Performs automated security testing against the running API to identify OWASP Top 10 vulnerabilities and other security issues. This runs the OWASP ZAP Docker container against the WebApi.

```powershell
.\scripts\runOwaspZap.ps1
```

ZAP reports are generated in the `zap-reports/` directory.

### 6. Threat Modeling

**Documentation**: `docs/Architecture.puml` and `.github/agents/threat-modeling-agent.yml`  
**Tool**: GitHub Copilot Agents  
**Purpose**: Leverage AI-assisted threat modeling to identify potential security threats in the application architecture. The PlantUML diagram can be used with Copilot agents to facilitate threat analysis discussions.

## 🚀 Getting Started

### Prerequisites

- Docker
- PowerShell

### Running the Application

**Backend (WebApi)**:

```powershell
cd src\WebApi
.\build.ps1
.\start.ps1
```

**Frontend**:

```powershell
cd src\Frontend
.\build.ps1
.\start.ps1
```

### Building for Production

**Backend**:

```powershell
cd src\WebApi
.\build.ps1
```

**Frontend**:

```powershell
cd src\Frontend
.\build.ps1
```

## 📁 Repository Structure

```
|-- .github/            # GitHub workflows for CI/CD
│   ├── agents/          # GitHub Copilot Agents configurations for threat modeling
├── src/
│   ├── Frontend/          # Vanilla JavaScript frontend
│   └── WebApi/           # ASP.NET Core Web API backend
├── scripts/              # Security scanning and utility scripts
├── sbom/                # Software Bill of Materials (not committed, generated via script)
├── zap-reports/         # OWASP ZAP security reports (not committed, generated via script)
├── docs/                # Architecture and threat modeling docs
```

## ⚠️ Important Notes

- This repository **intentionally contains vulnerabilities** for educational purposes
- Do **NOT** use this code in production without addressing the security issues
- The outdated SQL NuGet package is included deliberately to demonstrate vulnerability scanning

## 🤝 Contributing

This is a workshop repository. Feel free to fork and experiment with different security tools and practices.

## 📄 License

See [LICENSE](LICENSE) file for details.
