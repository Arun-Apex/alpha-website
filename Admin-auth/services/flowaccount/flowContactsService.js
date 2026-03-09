const FlowAccountOpenApi = require("@flowaccount/openapi-sdk");
const { getAccessToken } = require("./flowClient");
const { getFlowConfig } = require("./flowConfig");

function applyBasePath(api) {
  const cfg = getFlowConfig();
  if (api && typeof api.basePath !== "undefined") {
    api.basePath = cfg.apiBaseUrl;
  }
  return api;
}

async function listContacts(currentPage = 1, pageSize = 20) {
  const { accessToken } = await getAccessToken();

  const api = applyBasePath(new FlowAccountOpenApi.ContactsApi());

  try {
    const response = await api.contactsGet(
      `Bearer ${accessToken}`, // authorization
      currentPage,             // currentPage
      pageSize,                // pageSize
      undefined,               // sortBy
      undefined,               // filter
      undefined,               // searchString
      { headers: {} }          // options
    );

    return response;
  } catch (error) {
    error.statusCode = error.statusCode || error.status || 500;
    throw error;
  }
}

module.exports = {
  listContacts,
};