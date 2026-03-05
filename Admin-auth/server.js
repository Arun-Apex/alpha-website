const path = require("path");
const express = require("express");
const helmet = require("helmet");
const cookieParser = require("cookie-parser");

const { connectDb } = require("./db");

const usergroupsRoute = require("./routes/usergroups");
const authRoute = require("./routes/auth");
const meRoute = require("./routes/me");
const adminUsersRoute = require("./routes/admin.users");
const adminUsergroupsRoute = require("./routes/admin.usergroups");
const adminOmsRoute = require("./routes/admin.oms");

const app = express();
app.set("trust proxy", 1);

app.use(
  helmet({
    contentSecurityPolicy: false
  })
);
app.use(express.json({ limit: "1mb" }));
app.use(cookieParser());

// static UI
app.use("/admin", express.static(path.join(__dirname, "public")));

app.get("/health", (req, res) => res.json({ ok: true, time: new Date().toISOString() }));

// APIs
app.use("/admin/api/usergroups", usergroupsRoute);
app.use("/admin/api/auth", authRoute);
app.use("/admin/api/me", meRoute);
app.use("/admin/api/oms", adminOmsRoute);

// admin APIs
app.use("/admin/api/admin/users", adminUsersRoute);
app.use("/admin/api/admin/usergroups", adminUsergroupsRoute);

// fallback to index
app.get("/admin", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});
app.get("/admin/*", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI || "mongodb://localhost:27017/adminauth";

connectDb(MONGO_URI)
  .then(() => {
    app.listen(PORT, () => console.log(`Admin-auth running on :${PORT}`));
  })
  .catch((e) => {
    console.error("DB connect error:", e);
    process.exit(1);
  });