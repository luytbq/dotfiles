Translate a technical document from English to Vietnamese.

## Input

Read the file: $ARGUMENTS

## Instructions

1. Read the input file completely.
2. Translate the content from English to Vietnamese following the rules below.
3. Preserve the original file format (markdown, plain text, etc.) and structure exactly.

### What to translate:

- Descriptive prose, explanations, comments, documentation text
- Section headings and titles
- Table descriptions and labels (but not table data that is code/config)
- Bullet point descriptions

### What NOT to translate (keep original English):

- Code blocks and inline code (anything inside backticks or fenced code blocks)
- Class names, method names, function names, variable names, field names
- API paths, URLs, endpoints
- Project names, package names, library names, framework names
- File paths and file names
- JSON/XML/YAML structures and keys
- SQL statements and queries
- Command-line commands and flags
- Technical abbreviations and acronyms (e.g., API, REST, GET, POST, PUT, DELETE, HTTP, HTTPS, TCP, UDP, DNS, SSL, TLS, JWT, OAuth, CORS, CRUD, ORM, MVC, CI/CD, SDK, CLI, IDE, OOP, SOLID, DRY, KISS)
- Configuration keys and values
- Log format patterns
- Regular expressions
- Version numbers and semver strings
- Brand names and product names (e.g., Docker, Kubernetes, Redis, Kafka, Spring Boot, React)
- Popular technical terms that are commonly used in Vietnamese IT communities (e.g., alert, async, authenticate, authorize, backup, batch, branch, build, cache, callback, check, client, cluster, commit, component, consumer, container, cookie, dashboard, database, debug, deploy, encrypt, endpoint, gateway, hash, header, index, instance, load balancer, log, merge, microservice, middleware, migration, module, monitor, node, parse, payload, pipeline, plugin, pod, process, producer, production, proxy, pull, push, query, queue, release, render, request, response, restore, rollback, route, schema, serialize, server, session, socket, stream, sync, template, thread, token, topic, transaction, validate, server)

### Translation style:

- Use natural Vietnamese phrasing, not word-by-word translation
- Maintain consistent terminology throughout the document
- Preserve markdown formatting: headings, lists, bold, italic, links, images, tables, blockquotes

## Output

Write the translated file to the same directory as the input file, with `_vi` appended before the extension.
For example: `document.md` -> `document_vi.md`, `guide.txt` -> `guide_vi.txt`

Report the output file path when done.
