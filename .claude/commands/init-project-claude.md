# Init Project CLAUDE.md

Generate a CLAUDE.md file for the current project directory. This command explores the project structure and creates a concise guide for AI agents.

## Instructions

You are generating a CLAUDE.md file for the project in the current working directory. Follow these steps:

### Step 1: Detect Tech Stack
Check for these files (in order) to determine the project type:
- `pom.xml` → Java/Maven (read for Java version, dependencies, framework)
- `go.mod` → Go (read for Go version, key dependencies)
- `package.json` → Node.js/Angular/React (read for framework, version, scripts)
- `build.gradle` → Java/Gradle
- `Cargo.toml` → Rust
- `requirements.txt` / `pyproject.toml` → Python

### Step 2: Extract Key Details
Based on project type:

**Java/Maven:** Read `pom.xml` for:
- Java version (`maven.compiler.source` or `java.version`)
- Framework (look for vertx, spring-boot, spring-framework dependencies)
- Framework version
- Key dependencies (kafka, oracle-jdbc, postgresql, etc.)
- Packaging type (jar/war)

**Go:** Read `go.mod` for:
- Go version
- Key dependencies (gin, cobra, pgx, godror, kafka, etc.)
- Internal OnePay dependencies (git.onepay.vn/*)

**Angular:** Read `package.json` for:
- Angular version (`@angular/core`)
- Node/npm requirements (if specified in `engines`)
- Key scripts (build, serve, test)

### Step 3: Scan Project Structure
Run `ls` on the project root and key subdirectories (max 2 levels deep) to understand the layout. Identify:
- Source code directories
- Configuration files
- Deployment scripts
- Test directories

### Step 4: Identify Integration Points
Look for (quick scan, don't read deeply):
- HTTP client configurations (URLs to other services)
- Kafka topic names in config files
- Database connection config (Oracle vs PostgreSQL)
- Shared internal libraries

### Step 5: Write CLAUDE.md
Create a CLAUDE.md file in the project root with this structure:

```markdown
# <Project Name>

<1-2 sentence description of what this project does>

## Tech Stack

- **Language:** <language> <version>
- **Framework:** <framework> <version>
- **Database:** <Oracle/PostgreSQL/none>
- **Messaging:** <Kafka/ActiveMQ/none>
- **Build tool:** <Maven/Go modules/npm>

## Build & Run

\`\`\`bash
# Build
<build command>

# Run
<run command if detectable>

# Test
<test command>
\`\`\`

## Architecture

\`\`\`
<directory tree showing key folders and their purpose>
\`\`\`

<Brief description of the architectural pattern if identifiable>

## Key Dependencies

- <internal OnePay libraries>
- <external services this project calls>
- <message queues/topics>

## Notes

- <any gotchas, special config, or important patterns discovered>
```

### Rules
- Keep it **concise** — this is a reference card, not documentation
- Only include sections that have meaningful content
- Don't fabricate information — if you can't detect something, omit it
- If the project already has a CLAUDE.md, read it first and **update** it rather than overwriting
- Use the project's actual directory names and file paths
