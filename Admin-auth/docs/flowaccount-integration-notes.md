# FlowAccount Integration Notes

## Files created
- routes/admin.flowaccount.js
- services/flowaccount/flowConfig.js
- services/flowaccount/flowClient.js
- services/flowaccount/flowContactsService.js
- services/flowaccount/flowQuotationsService.js
- services/flowaccount/flowInvoicesService.js

## Required environment variables
- FLOWACCOUNT_API_BASE_URL=https://openapi.flowaccount.com/v1
- FLOWACCOUNT_CLIENT_ID=
- FLOWACCOUNT_CLIENT_SECRET=
- FLOWACCOUNT_SCOPE=flowaccount-api

## Next code changes to do manually
1. Install package:
   npm i flow_account_open_api

2. Mount route in server.js:
   const adminFlowAccountRoute = require("./routes/admin.flowaccount");
   app.use("/admin/api/flowaccount", adminFlowAccountRoute);

3. Add env vars to docker-compose.yml

4. Rebuild container
