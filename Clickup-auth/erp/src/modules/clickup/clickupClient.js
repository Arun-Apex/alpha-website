const config = require("../../config");

async function clickupFetch(url) {
  if (!config.clickupToken) throw new Error("CLICKUP_TOKEN not set");
  const res = await fetch(url, {
    headers: { Authorization: config.clickupToken }
  });
  const text = await res.text();
  let data = null;
  try { data = JSON.parse(text); } catch { data = { raw: text }; }
  if (!res.ok) {
    const msg = data?.err || data?.message || `ClickUp error ${res.status}`;
    throw new Error(msg);
  }
  return data;
}

// Pull tasks from a ClickUp List (pagination supported)
async function listTasks({ listId, includeClosed = true, page = 0 } = {}) {
  const lid = listId || config.clickupListId;
  if (!lid) throw new Error("CLICKUP_LIST_ID not set");

  const params = new URLSearchParams();
  params.set("page", String(page));
  params.set("include_closed", includeClosed ? "true" : "false");

  const url = `https://api.clickup.com/api/v2/list/${encodeURIComponent(lid)}/task?` + params.toString();
  return clickupFetch(url);
}

module.exports = { listTasks };
