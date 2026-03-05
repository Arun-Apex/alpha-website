require("dotenv").config();

function must(name, fallback) {
  const v = process.env[name] ?? fallback;
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

module.exports = {
  env: process.env.NODE_ENV || "production",
  port: Number(process.env.PORT || 3100),
  databaseUrl: must("DATABASE_URL", ""),
  clickupToken: process.env.CLICKUP_TOKEN || "",
  clickupListId: process.env.CLICKUP_LIST_ID || "",
  clickupListIdJobD: process.env.CLICKUP_LIST_ID_JOB_D,
  clickupListIdJobS: process.env.CLICKUP_LIST_ID_JOB_S,
  clickupIncludeClosed: String(process.env.CLICKUP_INCLUDE_CLOSED || "true").toLowerCase() === "true"
};
