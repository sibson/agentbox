As a developer I want to launch an internactive session using a CLI agent to make changes to the project in my current directory.

```agent-box codex```

Acceptance Critiera
 - A new interactive prompt with codex is started 
 - The Agent CLI session is running within the restrictied docker container
 - The Agent CLI session has full system access within and does not require approvals to run
 - Agent CLI has access to the local system directory from which it was launched