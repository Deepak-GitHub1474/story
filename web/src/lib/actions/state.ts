export type TFormState = { error: string | null; ok: string | null };

export const EMPTY: TFormState = { error: null, ok: null };

export type TAuthFormState = {
  error: string | null;
  field: string | null;
  userId?: string;
};

export const EMPTY_FORM: TAuthFormState = { error: null, field: null };
