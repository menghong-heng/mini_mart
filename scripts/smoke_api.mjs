const API = process.env.API_BASE_URL || "http://localhost:8001";
const WEB = process.env.WEB_BASE_URL || "http://localhost:5173";
const runId = Date.now();
const { readFile } = await import("node:fs/promises");

const staffAccounts = [
  ["Admin", "admin_user", "Admin@1234"],
  ["Admin", "admin_02", "Admin@1234"],
  ["Admin", "admin_03", "Admin@1234"],
  ["Admin", "admin_04", "Admin@1234"],
  ["Admin", "admin_05", "Admin@1234"],
  ["Sales", "sales_mgr", "Sales@1234"],
  ["Sales", "sales_02", "Sales@1234"],
  ["Sales", "sales_03", "Sales@1234"],
  ["Sales", "sales_04", "Sales@1234"],
  ["Sales", "sales_05", "Sales@1234"],
  ["Cashier", "cashier_01", "Cash@1234"],
  ["Cashier", "cashier_02", "Cash@1234"],
  ["Cashier", "cashier_03", "Cash@1234"],
  ["Cashier", "cashier_04", "Cash@1234"],
  ["Cashier", "cashier_05", "Cash@1234"],
  ["User", "user_01", "User@1234"],
  ["User", "user_02", "User@1234"],
  ["User", "user_03", "User@1234"],
  ["User", "user_04", "User@1234"],
  ["User", "user_05", "User@1234"],
];

function okStatus(status, expected) {
  return Array.isArray(expected) ? expected.includes(status) : status === expected;
}

async function request(base, path, options = {}) {
  const {
    method = "GET",
    token,
    body,
    expected = 200,
    label = `${method} ${path}`,
  } = options;

  const headers = { ...(options.headers || {}) };
  if (token) headers.Authorization = `Bearer ${token}`;
  const isForm = body instanceof FormData;
  if (body !== undefined && !isForm) headers["Content-Type"] = "application/json";

  const res = await fetch(`${base}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : isForm ? body : JSON.stringify(body),
  });

  const text = await res.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }

  if (!okStatus(res.status, expected)) {
    throw new Error(`${label} returned ${res.status}, expected ${expected}. Body: ${text}`);
  }

  return data;
}

async function loginStaff(username, password, expectedRole) {
  const data = await request(API, "/api/auth/login", {
    method: "POST",
    body: { username, password },
    label: `staff login ${username}`,
  });
  if (!data.token) throw new Error(`staff login ${username} did not return a token`);
  if (expectedRole && data.role !== expectedRole) {
    throw new Error(`staff login ${username} returned role ${data.role}, expected ${expectedRole}`);
  }
  return data.token;
}

async function logoutStaff(token) {
  await request(API, "/api/auth/logout", { method: "POST", token, label: "staff logout" });
}

async function main() {
  const results = [];
  const step = async (name, fn) => {
    await fn();
    results.push(name);
    console.log(`PASS ${name}`);
  };

  await step("frontend and public endpoints", async () => {
    await request(WEB, "/", { expected: 200, label: "frontend home" });
    await request(WEB, "/api/shop/products", { expected: 200, label: "frontend proxy shop products" });
    await request(API, "/health", { expected: 200, label: "backend health" });
    await request(API, "/api/shop/products", { expected: 200, label: "public shop products" });
  });

  await step("all staff accounts can login, read /me, and logout", async () => {
    for (const [role, username, password] of staffAccounts) {
      const token = await loginStaff(username, password, role);
      const me = await request(API, "/api/auth/me", { token, label: `staff me ${username}` });
      if (me.username !== username || me.role !== role) {
        throw new Error(`staff /me mismatch for ${username}`);
      }
      await logoutStaff(token);
    }
  });

  await step("admin account endpoints", async () => {
    const token = await loginStaff("admin_02", "Admin@1234", "Admin");
    await request(API, "/api/users", { token, label: "list users" });
    await request(API, "/api/roles", { token, label: "list roles" });
    await request(API, "/api/sessions", { token, label: "list sessions" });
    await request(API, "/api/audit-logs", { token, label: "list audit logs" });
    await request(API, "/api/system-config", { token, label: "list system config" });
    await request(API, "/api/reports/summary", { token, label: "summary report" });
    await request(API, "/api/reports/revenue", { token, label: "revenue report" });
    await request(API, "/api/dashboard/activity", { token, label: "dashboard activity" });
    await request(API, "/api/system-config/company_name", {
      method: "PATCH",
      token,
      body: { config_value: "67 Mini Mart" },
      label: "update company_name config",
    });

    const username = `smoke_user_${runId}`;
    const created = await request(API, "/api/users", {
      method: "POST",
      token,
      body: { username, password: "Smoke@1234", role_name: "User" },
      expected: 201,
      label: "create staff user",
    });
    await request(API, `/api/users/${created.user_id}/role`, {
      method: "PATCH",
      token,
      body: { role_name: "Sales" },
      label: "update staff user role",
    });
    await request(API, `/api/users/${created.user_id}/active`, {
      method: "PATCH",
      token,
      body: { is_active: false },
      label: "disable staff user",
    });
    await logoutStaff(token);
  });

  await step("stock endpoints", async () => {
    const token = await loginStaff("sales_02", "Sales@1234", "Sales");
    await request(API, "/api/products", { token, label: "list products" });
    await request(API, "/api/products/low-stock", { token, label: "low stock" });
    await request(API, "/api/categories", { token, label: "list categories" });
    await request(API, "/api/suppliers", { token, label: "list suppliers" });
    const imageLibrary = await request(API, "/api/product-images", { token, label: "list product image library" });

    const imageBytes = await readFile(new URL("../frontend/public/product-images/wireless-mouse.jpg", import.meta.url));
    const uploadForm = new FormData();
    uploadForm.append("label", `Smoke Image ${runId}`);
    uploadForm.append("file", new Blob([imageBytes], { type: "image/jpeg" }), `smoke-image-${runId}.jpg`);
    const uploadedImage = await request(API, "/api/product-images", {
      method: "POST",
      token,
      body: uploadForm,
      expected: 201,
      label: "upload product image",
    });

    const product = await request(API, "/api/products", {
      method: "POST",
      token,
      body: {
        name: `Smoke Product ${runId}`,
        category_id: 1,
        price: 1.99,
        stock_qty: 10,
        supplier_id: 1,
        image_url: imageLibrary[0]?.image_url || uploadedImage.image_url,
      },
      expected: 201,
      label: "create product",
    });
    await request(API, `/api/products/${product.product_id}/image`, {
      method: "PATCH",
      token,
      body: { image_url: uploadedImage.image_url },
      label: "assign product image",
    });
    await request(API, `/api/products/${product.product_id}/restock`, {
      method: "PATCH",
      token,
      body: { add_qty: 5 },
      label: "restock product",
    });
    await request(API, `/api/products/${product.product_id}/discontinue`, {
      method: "PATCH",
      token,
      label: "discontinue product",
    });
    await logoutStaff(token);
  });

  await step("sales endpoints", async () => {
    const token = await loginStaff("cashier_03", "Cash@1234", "Cashier");
    await request(API, "/api/customers", { token, label: "list customers" });
    await request(API, "/api/orders", { token, label: "list orders" });
    await request(API, "/api/orders/1", { token, label: "order detail" });
    await request(API, "/api/invoices", { token, label: "list invoices" });

    const order = await request(API, "/api/orders", {
      method: "POST",
      token,
      body: { customer_id: 1, items: [{ product_id: 7, quantity: 1 }] },
      expected: 201,
      label: "create order",
    });
    await request(API, `/api/orders/${order.order_id}/status`, {
      method: "PATCH",
      token,
      body: { status: "confirmed" },
      label: "update order status",
    });
    const invoice = await request(API, "/api/invoices", {
      method: "POST",
      token,
      body: { order_id: order.order_id, due_days: 7 },
      expected: 201,
      label: "create invoice",
    });
    await request(API, `/api/invoices/${invoice.invoice_id}/pay`, {
      method: "PATCH",
      token,
      label: "pay invoice",
    });
    await logoutStaff(token);
  });

  await step("role blocking checks", async () => {
    const token = await loginStaff("user_02", "User@1234", "User");
    await request(API, "/api/products", { token, label: "user can list products" });
    await request(API, "/api/products/low-stock", { token, expected: 403, label: "user blocked from low stock" });
    await request(API, "/api/orders", { token, label: "user can list orders" });
    await request(API, "/api/audit-logs", { token, expected: 403, label: "user blocked from audit logs" });
    await logoutStaff(token);
  });

  await step("customer auth and shop order flow", async () => {
    const email = `smoke.${runId}@example.com`;
    const password = "Customer@1234";
    const signup = await request(API, "/api/customer/signup", {
      method: "POST",
      body: { email, password, full_name: "Smoke Customer", phone: "000-000-0000" },
      expected: 201,
      label: "customer signup",
    });
    await request(API, "/api/customer/me", { token: signup.token, label: "customer me after signup" });
    await request(API, "/api/customer/logout", { method: "POST", token: signup.token, label: "customer logout" });

    const login = await request(API, "/api/customer/login", {
      method: "POST",
      body: { email, password },
      label: "customer login",
    });
    const order = await request(API, "/api/shop/orders", {
      method: "POST",
      token: login.token,
      body: { items: [{ product_id: 8, quantity: 1 }] },
      expected: 201,
      label: "customer create order",
    });
    await request(API, "/api/shop/orders/mine", { token: login.token, label: "customer list orders" });
    await request(API, `/api/shop/orders/${order.order_id}`, { token: login.token, label: "customer order detail" });
    await request(API, "/api/customer/logout", { method: "POST", token: login.token, label: "customer logout after order" });
  });

  console.log(`\n${results.length} smoke test groups passed.`);
}

main().catch(err => {
  console.error(`FAIL ${err.message}`);
  process.exit(1);
});
