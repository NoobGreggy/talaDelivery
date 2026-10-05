/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable @typescript-eslint/no-unused-vars */
/**
 * Runtime stub for `@nestjs/config` (pure ESM package). Type-only usages
 * resolve against the real package; this stub only needs to exist for any
 * residual value imports and provides a minimal `ConfigService`.
 */
export class ConfigService {
  get<T = unknown>(key: string, defaultValue?: T): T | undefined {
    return defaultValue;
  }

  getOrThrow<T = unknown>(key: string): T {
    throw new Error(`ConfigService.getOrThrow('${key}') is not implemented in jest stubs`);
  }
}

export class ConfigModule {
  static forRoot(options?: Record<string, unknown>): Record<string, unknown> {
    return {};
  }

  static forFeature(options?: Record<string, unknown>): Record<string, unknown> {
    return {};
  }
}