import { ValidationPipe } from '@nestjs/common';
import type { ValidationError } from 'class-validator';
import { ValidationError as AppValidationError } from './errors';

/**
 * Global validation pipe producing Laravel-shaped 422 errors:
 *   { success: false, message: "The given data was invalid.", errors: { field: string[] } }
 *
 * - whitelist: strips unknown properties
 * - transform: converts to DTO class instances
 * - plain outputs stay decimal strings (no implicit number coercion) so
 *   money fields serialize exactly like Laravel decimal casts.
 */
export function laravelValidationPipe(): ValidationPipe {
  return new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: false,
    transform: true,
    transformOptions: { enableImplicitConversion: false },
    exceptionFactory: (errors: ValidationError[]) => {
      const dict: Record<string, unknown> = {};
      for (const error of errors) {
        const messages: string[] = [];
        collectMessages(error, messages);
        if (messages.length > 0) {
          dict[error.property] = messages;
          if (error.constraints) {
            for (const [rule, message] of Object.entries(error.constraints)) {
              if (rule.includes('IsNumber') || rule.includes('IsInt')) {
                // numeric fields keep validation message first; no conversion
              }
              void message;
            }
          }
        }
      }
      return new AppValidationError('The given data was invalid.', dict);
    },
  });
}

function collectMessages(error: ValidationError, out: string[]): void {
  if (error.constraints) {
    out.push(...Object.values(error.constraints));
  }
  for (const child of error.children ?? []) {
    collectMessages(child, out);
  }
}