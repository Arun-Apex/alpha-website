#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"

if [ -d "$ROOT_DIR/Admin-auth" ]; then
  BASE_DIR="$ROOT_DIR/Admin-auth"
elif [ -f "$ROOT_DIR/package.json" ]; then
  BASE_DIR="$ROOT_DIR"
else
  echo "Error: could not determine Admin-auth base directory from '$ROOT_DIR'"
  echo "Run from repo root, from inside Admin-auth, or pass the correct path."
  exit 1
fi

echo "Creating FlowAccount folders under: $BASE_DIR"

mkdir -p "$BASE_DIR/routes"
mkdir -p "$BASE_DIR/services/flowaccount"
mkdir -p "$BASE_DIR/utils"
mkdir -p "$BASE_DIR/docs"

cat > "$BASE_DIR/services/flowaccount/flowConfig.js" <<'EOF'
function getFlowConfig() {
  return {
    apiBaseUrl: String(process.env.FLOWACCOUNT_API_BASE_URL || "https://openapi.flowaccount.com/v1").trim(),
    clientId: String(process.env.FLOWACCOUNT_CLIENT_ID || "").trim(),
    clientSecret: String(process.env.FLOWACCOUNT_CLIENT_SECRET || "").trim(),
    scope: String(process.env.FLOWACCOUNT_SCOPE || "flowaccount-api").trim(),
    grantType: "client_credentials",
    contentType: "application/x-www-form-urlencoded",
  };
}

function validateFlowConfig() {
  const cfg = getFlowConfig();
  const missing = [];

  if (!cfg.clientId) missing.push("FLOWACCOUNT_CLIENT_ID");
  if (!cfg.clientSecret) missing.push("FLOWACCOUNT_CLIENT_SECRET");

  return {
    ok: missing.length === 0,
    missing,
    config: cfg,
  };
}

module.exports = {
  getFlowConfig,
  validateFlowConfig,
};
EOF

cat > "$BASE_DIR/services/flowaccount/flowClient.js" <<'EOF'
const FlowAccountOpenApi = require("flow_account_open_api");
const { getFlowConfig, validateFlowConfig } = require("./flowConfig");

function configureApiClient() {
  const cfg = getFlowConfig();
  const defaultClient = FlowAccountOpenApi.ApiClient.instance;
  defaultClient.basePath = cfg.apiBaseUrl;
  return defaultClient;
}

async function getAccessToken() {
  const check = validateFlowConfig();
  if (!check.ok) {
    const err = new Error(`Missing FlowAccount env: ${check.missing.join(", ")}`);
    err.statusCode = 500;
    throw err;
  }

  configureApiClient();

  const cfg = getFlowConfig();
  const api = new FlowAccountOpenApi.AuthenticationApi();

  return new Promise((resolve, reject) => {
    api.tokenPost(
      cfg.contentType,
      {
        grantType: cfg.grantType,
        scope: cfg.scope,
        clientId: cfg.clientId,
        clientSecret: cfg.clientSecret,
      },
      (error, data, response) => {
        if (error) {
          error.statusCode = error.statusCode || response?.statusCode || 500;
          return reject(error);
        }

        const accessToken =
          data?.accessToken ||
          data?.access_token ||
          data?.token ||
          null;

        if (!accessToken) {
          const err = new Error("FlowAccount token missing in response");
          err.statusCode = 502;
          err.details = data || null;
          return reject(err);
        }

        resolve({
          accessToken,
          raw: data,
        });
      }
    );
  });
}

async function getAuthorizedApi(ApiClass) {
  configureApiClient();
  const { accessToken } = await getAccessToken();

  const api = new ApiClass();
  api.apiClient.defaultHeaders = {
    ...(api.apiClient.defaultHeaders || {}),
    Authorization: `Bearer ${accessToken}`,
  };

  return { api, accessToken };
}

module.exports = {
  configureApiClient,
  getAccessToken,
  getAuthorizedApi,
};
EOF

cat > "$BASE_DIR/services/flowaccount/flowContactsService.js" <<'EOF'
const FlowAccountOpenApi = require("flow_account_open_api");
const { getAuthorizedApi } = require("./flowClient");

async function listContacts(currentPage = 1, pageSize = 20) {
  const { api } = await getAuthorizedApi(FlowAccountOpenApi.ContactsApi);

  return new Promise((resolve, reject) => {
    api.contactsGet(currentPage, pageSize, (error, data) => {
      if (error) return reject(error);
      resolve(data);
    });
  });
}

module.exports = {
  listContacts,
};
EOF

cat > "$BASE_DIR/services/flowaccount/flowQuotationsService.js" <<'EOF'
function mapJobToQuotationPayload(job = {}) {
  const today = new Date().toISOString().slice(0, 10);

  const items = Array.isArray(job.items) && job.items.length
    ? job.items.map((item) => ({
        name: item.name || "Service Item",
        quantity: Number(item.quantity || 1),
        pricePerUnit: Number(item.pricePerUnit || 0),
        total: Number(item.total || (Number(item.quantity || 1) * Number(item.pricePerUnit || 0))),
        type: Number(item.type || 1),
        unitName: item.unitName || "unit",
        description: item.description || "",
      }))
    : [
        {
          name: job.itemName || "Service Item",
          quantity: Number(job.quantity || 1),
          pricePerUnit: Number(job.pricePerUnit || 0),
          total: Number(job.total || (Number(job.quantity || 1) * Number(job.pricePerUnit || 0))),
          type: 1,
          unitName: "unit",
          description: job.description || "",
        },
      ];

  const subTotal = items.reduce((sum, item) => sum + Number(item.total || 0), 0);

  return {
    contactName: job.contactName || job.customerName || "Customer",
    contactAddress: job.contactAddress || "",
    contactTaxId: job.contactTaxId || "",
    contactEmail: job.contactEmail || "",
    contactNumber: job.contactNumber || "",
    publishedOn: job.publishedOn || today,
    dueDate: job.dueDate || today,
    projectName: job.projectName || job.jobNo || "ERP Job",
    reference: job.reference || job.jobNo || "",
    isVatInclusive: Boolean(job.isVatInclusive || false),
    isVat: Boolean(job.isVat || false),
    subTotal,
    totalAfterDiscount: subTotal,
    grandTotal: subTotal,
    items,
    documentStructureType: "Simple document",
  };
}

module.exports = {
  mapJobToQuotationPayload,
};
EOF

cat > "$BASE_DIR/services/flowaccount/flowInvoicesService.js" <<'EOF'
function mapJobToInvoicePayload(job = {}) {
  const today = new Date().toISOString().slice(0, 10);

  const quantity = Number(job.quantity || 1);
  const pricePerUnit = Number(job.pricePerUnit || 0);
  const total = Number(job.total || quantity * pricePerUnit);

  return {
    contactName: job.contactName || job.customerName || "Customer",
    contactAddress: job.contactAddress || "",
    contactTaxId: job.contactTaxId || "",
    contactEmail: job.contactEmail || "",
    contactNumber: job.contactNumber || "",
    publishedOn: job.publishedOn || today,
    dueDate: job.dueDate || today,
    projectName: job.projectName || job.jobNo || "ERP Job",
    reference: job.reference || job.jobNo || "",
    isVatInclusive: Boolean(job.isVatInclusive || false),
    isVat: Boolean(job.isVat || false),
    subTotal: total,
    totalAfterDiscount: total,
    grandTotal: total,
    items: [
      {
        name: job.itemName || "Service Item",
        quantity,
        pricePerUnit,
        total,
        type: 1,
        unitName: job.unitName || "unit",
        description: job.description || "",
      },
    ],
    documentStructureType: "Simple document",
  };
}

module.exports = {
  mapJobToInvoicePayload,
};
EOF

cat > "$BASE_DIR/routes/admin.flowaccount.js" <<'EOF'
const express = require("express");
const { getAccessToken } = require("../services/flowaccount/flowClient");
const { validateFlowConfig } = require("../services/flowaccount/flowConfig");
const { listContacts } = require("../services/flowaccount/flowContactsService");

const router = express.Router();

let requireAuth = () => (req, res, next) => next();
try {
  ({ requireAuth } = require("../middleware/auth"));
} catch (_) {
}

router.get("/health", requireAuth(), async (req, res) => {
  try {
    const check = validateFlowConfig();

    res.json({
      ok: true,
      configured: check.ok,
      missing: check.missing,
      baseUrl: check.config.apiBaseUrl,
      scope: check.config.scope,
      grantType: check.config.grantType,
    });
  } catch (e) {
    res.status(500).json({
      ok: false,
      message: e.message || "flowaccount_health_failed",
    });
  }
});

router.post("/token/test", requireAuth(), async (req, res) => {
  try {
    const token = await getAccessToken();

    res.json({
      ok: true,
      hasToken: Boolean(token.accessToken),
      tokenPreview: token.accessToken ? `${token.accessToken.slice(0, 10)}...` : null,
      raw: token.raw || null,
    });
  } catch (e) {
    res.status(e.statusCode || 500).json({
      ok: false,
      message: e.message || "flowaccount_token_failed",
      details: e.details || null,
    });
  }
});

router.get("/contacts", requireAuth(), async (req, res) => {
  try {
    const currentPage = Number(req.query.page || 1);
    const pageSize = Number(req.query.pageSize || 20);

    const data = await listContacts(currentPage, pageSize);

    res.json({
      ok: true,
      data,
    });
  } catch (e) {
    res.status(e.statusCode || 500).json({
      ok: false,
      message: e.message || "flowaccount_contacts_failed",
      details: e.body || e.response?.body || null,
    });
  }
});

module.exports = router;
EOF

cat > "$BASE_DIR/docs/flowaccount-integration-notes.md" <<'EOF'
# FlowAccount Integration Notes

## Files created
- routes/admin.flowaccount.js
- services/flowaccount/flowConfig.js
- services/flowaccount/flowClient.js
- services/flowaccount/flowContactsService.js
- services/flowaccount/flowQuotationsService.js
- services/flowaccount/flowInvoicesService.js

## Required environment variables
- FLOWACCOUNT_API_BASE_URL=https://openapi.flowaccount.com/v1
- FLOWACCOUNT_CLIENT_ID=
- FLOWACCOUNT_CLIENT_SECRET=
- FLOWACCOUNT_SCOPE=flowaccount-api

## Next code changes to do manually
1. Install package:
   npm i flow_account_open_api

2. Mount route in server.js:
   const adminFlowAccountRoute = require("./routes/admin.flowaccount");
   app.use("/admin/api/flowaccount", adminFlowAccountRoute);

3. Add env vars to docker-compose.yml

4. Rebuild container
EOF

echo "Done."
echo
echo "Created:"
echo "  - $BASE_DIR/routes/admin.flowaccount.js"
echo "  - $BASE_DIR/services/flowaccount/flowConfig.js"
echo "  - $BASE_DIR/services/flowaccount/flowClient.js"
echo "  - $BASE_DIR/services/flowaccount/flowContactsService.js"
echo "  - $BASE_DIR/services/flowaccount/flowQuotationsService.js"
echo "  - $BASE_DIR/services/flowaccount/flowInvoicesService.js"
echo "  - $BASE_DIR/docs/flowaccount-integration-notes.md"