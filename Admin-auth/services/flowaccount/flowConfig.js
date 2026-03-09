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
