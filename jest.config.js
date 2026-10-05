/**
 * Root Jest configuration.
 * Discovers *.spec.ts in apps and libs; each project is its own Jest config,
 * so this root config is only used as a fallback aggregator (npm test).
 */
module.exports = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: '.',
  testRegex: '.*\\.spec\\.ts$',
  setupFiles: ['reflect-metadata'],
  transform: {
    '^.+\\.(t|j)s$': ['ts-jest', { tsconfig: 'tsconfig.json' }],
  },
  collectCoverageFrom: ['{apps,libs}/**/*.ts'],
  coverageDirectory: './coverage',
  testEnvironment: 'node',
  moduleNameMapper: {
    // NestJS 12 ships pure ESM packages ("type": "module"). Jest's CommonJS
    // runtime cannot parse them, so unit tests load the @nestjs/* runtime
    // stubs in test/jest-stubs/ (typechecking still uses the real packages).
    '^@nestjs/common$': '<rootDir>/test/jest-stubs/nest-common.ts',
    '^@nestjs/config$': '<rootDir>/test/jest-stubs/nest-config.ts',
    '^@nestjs/swagger$': '<rootDir>/test/jest-stubs/nest-swagger.ts',
    '^@nestjs/throttler$': '<rootDir>/test/jest-stubs/nest-throttler.ts',
    '^@nestjs/typeorm$': '<rootDir>/test/jest-stubs/nest-typeorm.ts',
    '^@taladelivery/([^/]+)$': '<rootDir>/libs/$1/src',
    '^@taladelivery/([^/]+)/(.*)$': '<rootDir>/libs/$1/src/$2',
  },
  testPathIgnorePatterns: ['/node_modules/', '/dist/'],
};