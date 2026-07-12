import type { FormErrors } from "fond";

export function BaseErrors({ errors }: { errors: FormErrors | null }) {
  if (!errors || errors.base.length === 0) return null;
  return (
    <div className="error-box" role="alert">
      {errors.base.map((m) => <p key={m}>{m}</p>)}
    </div>
  );
}

export function FieldErrors({ errors, field }: { errors: FormErrors | null; field: string }) {
  const messages = errors?.fields[field];
  if (!messages || messages.length === 0) return null;
  return <span className="field-error">{messages.join(", ")}</span>;
}
