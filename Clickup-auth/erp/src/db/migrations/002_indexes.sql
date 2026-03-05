CREATE INDEX IF NOT EXISTS idx_clickup_tasks_list_id ON clickup_tasks(list_id);
CREATE INDEX IF NOT EXISTS idx_clickup_tasks_updated_ms ON clickup_tasks(updated_ms DESC);
CREATE INDEX IF NOT EXISTS idx_clickup_tasks_status ON clickup_tasks(status);
