const config = require("../../config");
const { listTasks } = require("./clickupClient");
const { upsertTasks } = require("./clickupRepo");
const { log } = require("../../utils/logger");

async function syncList({ listId } = {}) {
  const lid = listId || config.clickupListId;
  if (!lid) throw new Error("CLICKUP_LIST_ID not set");

  let page = 0;
  let totalUpserted = 0;

  while (true) {
    const data = await listTasks({
      listId: lid,
      includeClosed: config.clickupIncludeClosed,
      page
    });

    const tasks = data?.tasks || [];
    const up = await upsertTasks(lid, tasks);
    totalUpserted += up;

    log(`ClickUp sync page=${page} tasks=${tasks.length} upserted=${up}`);

    // ClickUp returns last_page boolean sometimes; also safe stop if tasks empty
    if (!tasks.length || data?.last_page === true) break;

    page++;
    if (page > 50) break; // safety cap
  }

  return { ok: true, listId: lid, upserted: totalUpserted };
}

module.exports = { syncList };
