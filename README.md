# Azure Cloud Resume Challenge — Backend

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Azure Functions](https://img.shields.io/badge/Azure%20Functions-Python%20v2%20model-0062AD)](https://learn.microsoft.com/azure/azure-functions/)

The back-end API for my submission to the [Cloud Resume Challenge](https://cloudresumechallenge.dev/docs/the-challenge/azure/) on Microsoft Azure. It's an HTTP-triggered Azure Function, written in Python using the v2 (decorator-based) programming model, that atomically increments and returns a visitor count stored in Azure Table Storage.

> 🔗 **Related repository:** [Azure-Cloud-Resume-frontend](https://github.com/DonKubini/Azure-Cloud-Resume-frontend) — the static resume site that consumes this API.

## Overview

```
Frontend (Azure Storage static site)
        │  GET /api/GetResumeCounter
        ▼
Azure Function (Python, HTTP trigger)
        │  read / increment / write
        ▼
Azure Table Storage — "Counter" table
```

Each request reads the current count from the `Counter` table, increments it by one, persists the update, and returns the new value as plain text — used by the frontend to render a live "profile views" counter.

## Tech Stack

| Layer | Technology |
|---|---|
| Runtime | Python 3.12, Azure Functions v2 programming model |
| Trigger | HTTP trigger, anonymous auth |
| Compute | Azure Linux Function App, Consumption plan (Y1) |
| Data store | Azure Cosmos DB (Table API) — `Counter` table |
| Key dependencies | `azure-core`, `azure-data-tables`, `azure-cosmos`, `requests` |
| Infrastructure as Code | Terraform (`infrastructure/`) |
| CI/CD auth | GitHub OIDC federation → Azure Managed Identity (no stored secrets) |

## Repository Structure

```
.
├── function_app.py       # HTTP-triggered "GetResumeCounter" function
├── host.json              # Function host configuration (extension bundle, logging)
├── requirements.txt        # Python dependencies
├── infrastructure/        # Terraform: Cosmos DB (Table API), Function App, OIDC identity
├── tests/
│   └── test_function.py   # Unit test for GetResumeCounter (mocked Table Client)
├── .funcignore
├── .gitignore
├── LICENSE                 # MIT
└── README.md
```

## API Reference

### `GET /api/GetResumeCounter`

Increments the stored visitor count and returns the new value.

**Response** `200 OK`
```text
42
```

- On first invocation (no existing entity), the counter is initialized at `1`.
- Authentication level: anonymous — no function key required.

## How It Works

`function_app.py` uses the Azure Functions Python v2 model to register a single HTTP-triggered route:

```python
app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="GetResumeCounter", auth_level=func.AuthLevel.ANONYMOUS)
def GetResumeCounter(req: func.HttpRequest) -> func.HttpResponse:
    ...
```

Internally, it uses an `azure.data.tables.TableClient` to read the entity at `PartitionKey="resume"`, `RowKey="visitor_count"` from a table named `Counter`:

- If the entity exists, its `Count` field is incremented and the entity is updated (`mode="replace"`).
- If it doesn't exist yet (`ResourceNotFoundError`), a new entity is created with `Count = 1`.
- The resulting count is returned as the response body.

## Configuration

The function expects a single application setting / environment variable:

| Name | Description |
|---|---|
| `COSMOS_CONNECTION_STRING` | Connection string for the Cosmos DB account's **Table API** endpoint, backing the `Counter` table. Provisioned automatically by Terraform (see below), which assembles it from the Cosmos account's name and primary key, targeting `https://<account>.table.cosmos.azure.com:443/`. |

CORS is also configured server-side (in Terraform, not in code) to allow requests only from the production frontend origin and `localhost:7071` for local testing — update `infrastructure/`'s `cors.allowed_origins` if you deploy under a different domain.

## Infrastructure

Provisioned with **Terraform** (`infrastructure/`), building on the resource group created in the frontend's Terraform phase. It defines:

| Resource | Purpose |
|---|---|
| `data.azurerm_resource_group` | References the existing resource group (created elsewhere, not by this module) |
| `azurerm_cosmosdb_account` (Table API, free tier) | Backing datastore, `Session` consistency, single-region |
| `azurerm_cosmosdb_table` | The `Counter` table (400 RU/s provisioned throughput) |
| `azurerm_storage_account` | Storage account required internally by the Function App runtime |
| `azurerm_service_plan` (Linux, Y1) | Consumption plan hosting the function |
| `azurerm_linux_function_app` | The Function App itself — Python 3.12, CORS restricted to the production frontend origin + `localhost:7071`, `COSMOS_CONNECTION_STRING` wired in automatically from the Cosmos account's outputs |
| `azurerm_user_assigned_identity` | Dedicated managed identity for GitHub Actions deployments |
| `azurerm_role_assignment` | Grants the identity **Contributor** on the resource group (needed to publish the Function App) |
| `azurerm_federated_identity_credential` | OIDC trust between the identity and this GitHub repo's `main` branch — no client secrets stored in GitHub |

Required Terraform variables:

| Variable | Description |
|---|---|
| `resource_group_name` | Name of the **existing** resource group (shared with the frontend) |
| `cosmos_account_name` | Globally-unique Cosmos DB account name |
| `function_storage_account_name` | Globally-unique storage account name for the Function App |
| `function_app_name` | Globally-unique Function App name |
| `github_repository` | `owner/repo` used to scope the OIDC federation's `subject` claim |

```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

> ⚠️ The Cosmos DB connection string (containing the account's primary key) is written into the Function App's `app_settings` as a plaintext Terraform output. Treat your `.tfstate` as sensitive and store it in a secured remote backend rather than committing it to source control.

## Local Development

Prerequisites: [Python 3.10+](https://www.python.org/), [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local), and an accessible Table Storage / Cosmos DB Table API account (e.g. via [Azurite](https://learn.microsoft.com/azure/storage/common/storage-use-azurite) for local emulation).

```bash
git clone https://github.com/DonKubini/Azure-Cloud-Resume-backend.git
cd Azure-Cloud-Resume-backend

python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# Add local.settings.json (see Configuration above), then:
func start
```

The function will be available locally at `http://localhost:7071/api/GetResumeCounter`.

## Testing

`tests/test_function.py` unit-tests `GetResumeCounter` in isolation — no live Azure resources required. It patches `TableClient.from_connection_string` so the test runs entirely against a `MagicMock`:

- Mocks `get_entity` to return an existing entity with `Count = 5`.
- Invokes the function directly with a fake `func.HttpRequest`.
- Asserts the response is `200` with body `b"6"` (the count incremented by one).
- Asserts `update_entity` was called exactly once, confirming the write path ran.

`COSMOS_CONNECTION_STRING` is patched to a dummy value via `unittest.mock.patch.dict`, so no real credentials or connectivity are needed to run the suite.

```bash
pip install pytest
pytest tests/
```

## Deployment

1. Apply the Terraform in `infrastructure/` to provision Cosmos DB, the Function App, and the OIDC-federated managed identity (see **Infrastructure** above).
2. In GitHub, configure the repo's Actions to authenticate via the federated identity (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` as repo/environment variables — no secrets needed).
3. On push to `main`, have a GitHub Actions workflow log in via OIDC and run `func azure functionapp publish <FUNCTION_APP_NAME>` (or the equivalent `azure/functions-action`).
4. Confirm the frontend's `apiUrl` points at `https://<FUNCTION_APP_NAME>.azurewebsites.net/api/GetResumeCounter` and that its origin is included in the Function App's `cors.allowed_origins`.

## Roadmap

- [ ] Move the Cosmos DB connection string to Key Vault / managed identity auth instead of an account key in `app_settings`

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for details.

## Author

**Jakub Šišma**
[GitHub](https://github.com/DonKubini) · [LinkedIn](https://linkedin.com/in/jakub-šišma-7b31871b5/)
