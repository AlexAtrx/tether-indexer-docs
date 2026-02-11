**Task:** Fix the tests for the `wdk-data-shard` worker.

### **Reference Materials**

1. There is an internal guide written by another developer that the team likes.
   Location: `_docs/tasks/fix_tests_for_wdk-data-shard_worker/rpc.standard.e2e.test.js`

2. The helper library used in these tests is here (read before proceeding):
   **[https://github.com/tetherto/tether-svc-test-helper](https://github.com/tetherto/tether-svc-test-helper)**

   - The first helper function in that repo shows its intended usage.
   - The team regularly uses this library; it is reliable.
   - Importantly, it exposes RPC keys so logs don’t need to be parsed.

### **Worker / Client Usage Examples**

**Example from our codebase:**

```js
const { createWorker } = require("./lib/worker");
const createClient = require("./lib/client");

const worker = createWorker({ ...config });
await worker.start();

const client = createClient(worker);
await client.connect();

const response = await client.request("ping", { message: "Hello, Tether!" });
console.log(response);

await client.stop();
await worker.stop();
```

**Example from the README showing how to get the RPC key:**

```js
const procKey = procWorker.worker.getRpcKey();
```

> Note: Getting the RPC key is essential but not documented clearly in the README.

**Using the RPC key when starting the API worker:**

```js
apiWorker = createWorker({
  wtype: "wrk-btc-indexer-api",
  env: "test",
  rack: "btc-api-e2e",
  chain: "bitcoin",
  procRpc: procKey,
  serviceRoot: path.join(__dirname, "../.."),
});
```

**Conceptual model:**

- **Workers** are created via `createWorker()` and can expose RPC keys.
- **Clients** are created via `createClient(worker)` and are used to make RPC calls to workers.
- Tests should correctly start/stop workers, create clients, fetch RPC keys when needed, and call RPC methods.

### **Goal**

Using all information above, update and fix the test suite for the `wdk-data-shard` worker so that:

- RPC clients connect properly
- Workers expose and use the correct RPC keys
- Test flows follow the start → connect → request → stop lifecycle
- Test helper usage follows the patterns demonstrated in the reference examples and helper library documentation.
