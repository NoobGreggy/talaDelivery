/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable @typescript-eslint/no-unused-vars */
/**
 * Runtime stub for `@nestjs/typeorm` (pure ESM package). Unit tests build
 * repositories manually, so only the decorator factories need to exist.
 */
export function InjectRepository(entity: Function): ParameterDecorator {
  return () => undefined;
}

export function InjectDataSource(dataSource?: unknown): ParameterDecorator {
  return () => undefined;
}

export function InjectEntityManager(entityManager?: unknown): ParameterDecorator {
  return () => undefined;
}

export const TypeOrmModule = {
  forRoot(): Record<string, unknown> {
    return {};
  },
  forFeature(): Record<string, unknown> {
    return {};
  },
};