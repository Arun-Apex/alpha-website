const mongoose = require("mongoose");

const UserSchema = new mongoose.Schema(
  {
    username: { type: String, required: true, unique: true, lowercase: true, trim: true },
    displayName: { type: String, default: "" },
    email: { type: String, default: "" },
    passwordHash: { type: String, required: true },

    // System-level role: only these can manage users
    systemRole: { type: String, enum: ["owner", "superadmin", "user"], default: "user" },

    // Operational group (what your UI shows)
    groupKey: { type: String, required: true },

    status: { type: String, enum: ["active", "disabled"], default: "active" },

    lastLoginAt: { type: Date, default: null }
  },
  { timestamps: true }
);

module.exports = mongoose.model("User", UserSchema);