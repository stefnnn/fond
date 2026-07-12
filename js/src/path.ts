function snakeToCamel(segment: string): string {
  return segment.replace(/_([a-z0-9])/g, (_, c: string) => c.toUpperCase());
}

function stringifyValue(value: unknown): string | null {
  if (value === null || value === undefined || value === "") return null;
  if (value instanceof Date) return value.toISOString();
  if (typeof value === "boolean" || typeof value === "number") {
    return String(value);
  }
  return String(value);
}

export function interpolatePath(
  pattern: string,
  params: Record<string, unknown>,
): { path: string; usedKeys: Set<string> } {
  const usedKeys = new Set<string>();

  const path = pattern.replace(/:([a-zA-Z0-9_]+)/g, (_, name: string) => {
    const key = snakeToCamel(name);
    if (!(key in params) || params[key] === null || params[key] === undefined) {
      throw new Error(`fond: missing path param "${name}" for pattern "${pattern}"`);
    }
    usedKeys.add(key);
    const value = stringifyValue(params[key]);
    return encodeURIComponent(value ?? "");
  });

  return { path, usedKeys };
}

export function buildPath(
  pattern: string,
  pathParams: string[],
  params: Record<string, unknown> = {},
): string {
  const pathParamKeys = new Set(pathParams.map(snakeToCamel));
  const { path, usedKeys } = interpolatePath(pattern, params);

  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (pathParamKeys.has(key) && usedKeys.has(key)) continue;
    const stringified = stringifyValue(value);
    if (stringified === null) continue;
    query.append(key, stringified);
  }

  const queryString = query.toString();
  return queryString ? `${path}?${queryString}` : path;
}
