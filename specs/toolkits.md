As a user I want to be able to preconfigure the Docker image with tools for my usecase.
I can select toolkits via the configuration file.
Toolkits are defined in `toolkits/`; each toolkit is a list of apt packages or direct downloads.

Config format (project `.agentbox` or `~/.agentbox`):
```toml
[toolkits]
selected = ["python", "c_cpp"]
```

Built-in toolkits
- Toolchains
  - `c_cpp`
  - `python`
  - `java`
- General environments
  - `web` (node ecosystem helpers)
  - `datascience`
