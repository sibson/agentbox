As a developer I want a secure docker image that allows me to run agents in a sandboxed environtment

The docker image should support running
 - Codex
 - Claude Code

The default Docker image is Debian server but if future we should also be able to support other base images.

# - codex-universal


Acceptance Critiera
 - Within the image the agent does not have network access
 - Within the image the agent can not gain root access via any mechisim
