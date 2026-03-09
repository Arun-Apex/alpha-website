const FlowAccountOpenApi = require("@flowaccount/openapi-sdk");
const { getFlowConfig, validateFlowConfig } = require("./flowConfig");

function applyBasePath(api) {
  const cfg = getFlowConfig();
  if (api && typeof api.basePath !== "undefined") {
    api.basePath = cfg.apiBaseUrl;
  }
  return api;
}

async function getAccessToken() {
  const check = validateFlowConfig();
  if (!check.ok) {
    const err = new Error(`Missing FlowAccount env: ${check.missing.join(", ")}`);
    err.statusCode = 500;
    throw err;
  }

  const cfg = getFlowConfig();
  const api = applyBasePath(new FlowAccountOpenApi.AuthenticationApi());

  try {
    const response = await api.tokenPost(
      cfg.contentType,
      cfg.grantType,
      cfg.scope,
      cfg.clientId,
      cfg.clientSecret,
      undefined,
      { headers: {} }
    );

    const accessToken =
      response?.accessToken ||
      response?.access_token ||
      response?.token ||
      response?.body?.accessToken ||
      response?.body?.access_token ||
      response?.data?.accessToken ||
      response?.data?.access_token ||
      response?.response?.body?.accessToken ||
      response?.response?.body?.access_token ||
      null;

    if (!accessToken) {
      const err = new Error("FlowAccount token missing in response");
      err.statusCode = 502;
      err.details = response || null;
      throw err;
    }

    return {
      accessToken,
      raw: response,
    };
  } catch (error) {
    error.statusCode = error.statusCode || error.status || 500;
    throw error;
  }
}

async function getAuthorizedApi(ApiClass) {
  const { accessToken } = await getAccessToken();
  const api = applyBasePath(new ApiClass());

  api.defaultHeaders = {
    ...(api.defaultHeaders || {}),
    Authorization: `Bearer ${accessToken}`,
  };

  if (api.apiClient) {
    api.apiClient.defaultHeaders = {
      ...(api.apiClient.defaultHeaders || {}),
      Authorization: `Bearer ${accessToken}`,
    };
  }

  return { api, accessToken };
}

module.exports = {
  getAccessToken,
  getAuthorizedApi,
};