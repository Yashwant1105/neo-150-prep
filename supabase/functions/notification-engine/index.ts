import { buildRuntimeHandler } from "./runtime.ts";

const handler = buildRuntimeHandler();

export default {
  fetch: handler.fetch,
};
