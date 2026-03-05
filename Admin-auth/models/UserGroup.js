const mongoose = require("mongoose");

const UserGroupSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true, lowercase: true, trim: true },
    name: {
      th: { type: String, required: true },
      en: { type: String, required: true }
    },
    description: {
      th: { type: String, default: "" },
      en: { type: String, default: "" }
    },
    icon: { type: String, default: "" },
    defaultRoute: { type: String, default: "/app/" },
    permissions: { type: [String], default: [] },
    active: { type: Boolean, default: true },
    sort: { type: Number, default: 100 }
  },
  { timestamps: true }
);

module.exports = mongoose.model("UserGroup", UserGroupSchema);