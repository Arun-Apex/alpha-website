CREATE TABLE IF NOT EXISTS clickup_tasks (
  task_id        TEXT PRIMARY KEY,
  list_id        TEXT NOT NULL,
  name           TEXT NOT NULL,
  status         TEXT,
  status_type    TEXT,
  assignees      TEXT,
  due_date_ms    BIGINT,
  created_ms     BIGINT,
  updated_ms     BIGINT,
  url            TEXT,
  raw            JSONB NOT NULL,
  synced_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
