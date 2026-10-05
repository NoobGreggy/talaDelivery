/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable @typescript-eslint/no-unused-vars */
/**
 * Runtime stub for `@nestjs/swagger` (pure ESM package). Swagger UI setup only
 * runs inside `configureHttpApp()` which unit tests never call, so these are
 * chainable no-ops.
 */
export class DocumentBuilder {
  setTitle(title: string): this {
    return this;
  }

  setDescription(description: string): this {
    return this;
  }

  setVersion(version: string): this {
    return this;
  }

  addBearerAuth(): this {
    return this;
  }

  addTag(name: string): this {
    return this;
  }

  build(): Record<string, unknown> {
    return {};
  }
}

export const SwaggerModule = {
  createDocument(): Record<string, unknown> {
    return {};
  },
  setup(): void {
    // no-op
  },
};