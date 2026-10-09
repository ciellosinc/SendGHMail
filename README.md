# SendGHMail

## Ciellos fork (ciellosinc) changes
Forked from [eh-ciellos](https://github.com/eh-ciellos) (Emanuele Hamzaraj) and fixed for use in AL-Go repositories:
- All inputs are passed to the scripts via environment variables (no quoting issues, no script injection, secrets not on the command line).
- Use tag `v1` (or `v1.0.0`) in workflows: `uses: ciellosinc/<repo>@v1`.
- `CcEmail` input is declared and optional (empty CC no longer breaks sending); `FromEmail` has no default.
- Uses the Microsoft Graph REST API directly (client credentials); the Microsoft.Graph PowerShell module is no longer required.
- Supports secretless authentication: if `AzureCredentialsJson` has no `clientSecret`, the GitHub OIDC token is used (Entra federated credential). The job needs `permissions: id-token: write`. The subject claim is printed in the log to help set up the federated credential.
