import { useCallback, useState } from "react";
import { FondParamsError, navigate } from "./router.js";
import { interpolatePath } from "./path.js";

export interface FormErrors {
  base: string[];
  fields: Record<string, string[]>;
}

export type MutationOutcome<R> =
  | { ok: true; redirected: boolean; data: R | null }
  | { ok: false; errors: FormErrors };

export interface Mutation<P, R> {
  mutate: (params: P) => Promise<MutationOutcome<R>>;
  pending: boolean;
  errors: FormErrors | null;
  reset: () => void;
}

function csrfToken(): string | null {
  const meta = document.querySelector('meta[name="csrf-token"]');
  return meta?.getAttribute("content") ?? null;
}

export function useMutation<P extends object, R = null>(
  pattern: string,
  method: "post" | "patch" | "put" | "delete",
  pathParams: string[] = [],
): Mutation<P, R> {
  const [pending, setPending] = useState(false);
  const [errors, setErrors] = useState<FormErrors | null>(null);

  const mutate = useCallback(
    async (params: P): Promise<MutationOutcome<R>> => {
      setPending(true);
      try {
        const { path } = interpolatePath(pattern, params as Record<string, unknown>);

        const headers: Record<string, string> = {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-Fond": "true",
        };
        const token = csrfToken();
        if (token !== null) headers["X-CSRF-Token"] = token;

        const response = await fetch(path, {
          method: method.toUpperCase(),
          credentials: "same-origin",
          headers,
          body: JSON.stringify(params),
        });

        if (response.status === 200) {
          const body = (await response.json()) as { redirect?: string; props?: unknown };
          if (body.redirect !== undefined) {
            void navigate(body.redirect);
            setErrors(null);
            return { ok: true, redirected: true, data: null };
          }
          setErrors(null);
          return { ok: true, redirected: false, data: (body.props ?? null) as R | null };
        }

        if (response.status === 422) {
          const body = (await response.json()) as { errors: FormErrors };
          setErrors(body.errors);
          return { ok: false, errors: body.errors };
        }

        if (response.status === 400) {
          const body = (await response.json()) as {
            error?: string;
            errors?: Record<string, string>;
          };
          if (body.error === "invalid_params") {
            throw new FondParamsError(body.errors ?? {});
          }
          throw new Error("fond: mutation failed with status 400");
        }

        throw new Error(`fond: mutation failed with status ${response.status}`);
      } finally {
        setPending(false);
      }
    },
    [pattern, method, ...pathParams],
  );

  const reset = useCallback(() => setErrors(null), []);

  return { mutate, pending, errors, reset };
}
