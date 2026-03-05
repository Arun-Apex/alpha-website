const express = require("express");
const config = require("./config");
const db = require("./db");
const { log, error } = require("./utils/logger");

const clickupRoutes = require("./modules/clickup/clickupRoutes");

const app = express();
app.use(express.json({ limit: "2mb" }));

// serve UI
app.use("/ui", express.static("public/ui"));

// health
app.get("/health", async (req, res) => {
  const dbOk = await db.healthcheck().catch(() => false);
  res.json({ ok: true, service: "clickup-erp", dbOk, time: new Date().toISOString() });
});

// clickup + api routes
app.use(clickupRoutes);

// error handler
app.use((err, req, res, next) => {
  error("ERR", err);
  res.status(500).json({ message: "Server error" });
});

app.listen(config.port, "0.0.0.0", () => {
  log(`clickup-erp running on :${config.port}`);
});
