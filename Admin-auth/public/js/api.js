const API_BASE = "/admin/api";

function getToken() {
  return sessionStorage.getItem("accessToken");
}

async function apiFetch(url, options = {}) {
  const token = getToken();

  const headers = {
    ...(options.headers || {}),
  };

  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  const res = await fetch(url, {
    ...options,
    headers,
    credentials: "include"
  });

  return res;
}

async function apiGet(url) {
  const res = await apiFetch(url);
  return res.json();
}

async function apiPost(url, body) {
  const res = await apiFetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
  return res.json();
}