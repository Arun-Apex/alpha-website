const bcrypt = require("bcrypt");
const { connectDb } = require("./db");
const UserGroup = require("./models/UserGroup");
const User = require("./models/User");

async function run() {
  const MONGO_URI = process.env.MONGO_URI || "mongodb://localhost:27017/adminauth";
  await connectDb(MONGO_URI);

  const groups = [
    {
      key: "supervisor",
      name: { th: "Supervisor / Manager", en: "Supervisor / Manager" },
      description: { th: "จัดการระบบ และปรับสถานะงานได้", en: "Manage system and update job status" },
      icon: "user",
      defaultRoute: "/app/supervisor",
      permissions: ["orders.read.all", "orders.update", "comments.read.all", "comments.write"],
      sort: 10,
      active: true
    },
    {
      key: "admin",
      name: { th: "แอดมิน", en: "Administrator" },
      description: { th: "จัดการระบบ และปรับสถานะงานได้", en: "Full system administration" },
      icon: "shield",
      defaultRoute: "/app/admin",
      permissions: ["orders.read.all", "orders.create", "orders.update", "users.manage", "comments.read.all", "comments.write"],
      sort: 20,
      active: true
    },
    {
      key: "graphic",
      name: { th: "กราฟิก", en: "Graphic Designer" },
      description: { th: "วางแบบและคอมพิวเตอร์แบบ", en: "Design and artwork preparation" },
      icon: "pen",
      defaultRoute: "/app/graphic",
      permissions: ["orders.read.assigned", "comments.write", "comments.read.assigned"],
      sort: 30,
      active: true
    },
    {
      key: "print",
      name: { th: "ช่างพิมพ์", en: "Printing Technician" },
      description: { th: "เช็คงานพิมพ์และแจ้งสถานะงานพิมพ์เสร็จ", en: "Print production and update completion status" },
      icon: "printer",
      defaultRoute: "/app/print",
      permissions: ["orders.read.assigned", "orders.update.assigned", "comments.write", "comments.read.assigned"],
      sort: 40,
      active: true
    },
    {
      key: "install",
      name: { th: "ช่างติดตั้ง", en: "Installation Technician" },
      description: { th: "ติดตั้ง และทำงานหน้างานตามรายการ", en: "On-site installation and task execution" },
      icon: "home",
      defaultRoute: "/app/install",
      permissions: ["orders.read.assigned", "orders.update.assigned", "comments.write", "comments.read.assigned"],
      sort: 50,
      active: true
    }
  ];

  for (const g of groups) {
    await UserGroup.updateOne({ key: g.key }, { $set: g }, { upsert: true });
  }

  const ownerUsername = (process.env.OWNER_USER || "owner").toLowerCase();
  const ownerPass = process.env.OWNER_PASS || "Owner@12345";

  const existingOwner = await User.findOne({ username: ownerUsername });
  if (!existingOwner) {
    const passwordHash = await bcrypt.hash(ownerPass, 10);
    await User.create({
      username: ownerUsername,
      displayName: "System Owner",
      email: "",
      passwordHash,
      systemRole: "owner",
      groupKey: "admin",
      status: "active"
    });
    console.log("✅ Created owner user:", ownerUsername, "password:", ownerPass);
  } else {
    console.log("ℹ️ Owner already exists:", ownerUsername);
  }

  console.log("✅ Seed complete");
  process.exit(0);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});