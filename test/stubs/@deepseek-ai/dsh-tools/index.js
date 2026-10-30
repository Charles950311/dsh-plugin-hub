// Local test double for @deepseek-ai/dsh-tools, which ships inside the harness.
// Mirrors the parts of defineTool that matter for exercising a plugin outside
// DSH: parameter-spec conversion, arg validation, and a registry-ready object.
// Not published; node_modules/ is git-ignored.

function specToJsonSchema(spec = {}) {
  const properties = {};
  const required = [];
  for (const [key, value] of Object.entries(spec)) {
    const { description, ...rest } = value ?? {};
    properties[key] = { ...rest };
    if (description) properties[key].description = description;
    if (rest.required) {
      required.push(key);
      delete properties[key].required;
    }
  }
  return { type: "object", properties, required, additionalProperties: false };
}

function validate(schema, value) {
  const problems = [];
  if (schema?.type === "object") {
    const props = schema.properties ?? {};
    for (const key of schema.required ?? []) {
      if (!(key in (value ?? {}))) problems.push(`missing ${key}`);
    }
    for (const [key, sub] of Object.entries(props)) {
      const v = value?.[key];
      if (v === undefined) continue;
      if (sub.type === "string" && typeof v !== "string") problems.push(`${key} must be string`);
      if (sub.type === "integer" && !Number.isInteger(v)) problems.push(`${key} must be integer`);
      if (sub.type === "boolean" && typeof v !== "boolean") problems.push(`${key} must be boolean`);
      if (sub.type === "array" && !Array.isArray(v)) problems.push(`${key} must be array`);
    }
  }
  return problems;
}

export function defineTool(options) {
  const parameters = specToJsonSchema(options.parameters);
  return {
    name: options.name,
    description: options.description,
    parameters,
    output: options.output,
    async execute(args = {}, exec) {
      const problems = validate(parameters, args);
      if (problems.length) throw new Error(`bad args: ${problems.join(", ")}`);
      return options.execute(args, exec);
    },
  };
}

export default { defineTool };
