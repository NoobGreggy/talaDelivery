import { plainToInstance } from 'class-transformer';
import { validateSync, type ValidationError } from 'class-validator';

/**
 * Validates an environment schema at startup and fails fast when config is
 * missing/invalid (nestjs_api.md §20.6).
 */
export function createEnvValidator(schema: new () => object) {
  return (config: Record<string, unknown>): Record<string, unknown> => {
    const validated = plainToInstance(schema, config, {
      enableImplicitConversion: true,
    });

    const errors: ValidationError[] = validateSync(validated as object, {
      whitelist: true,
      forbidUnknownValues: false,
      skipMissingProperties: false,
    });

    if (errors.length > 0) {
      const details = errors
        .flatMap((error) => Object.values(error.constraints ?? {}))
        .map((message) => `- ${message}`);
      throw new Error(`Environment configuration is invalid:\n${details.join('\n')}`);
    }

    return validated as unknown as Record<string, unknown>;
  };
}