/**
 * E2E test configuration. Gateways/suites are defined per-app under apps/*/test/.
 * Runs in-band with a real stack (Postgres + Redis) in the compose flow.
 */
module.exports = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: '.',
  testRegex: '.*\\.e2e-spec\\.ts$',
  transform: {
    '^.+\\.(t|j)s$': ['ts-jest', { tsconfig: 'tsconfig.json' }],
  },
  testEnvironment: 'node',
  moduleNameMapper: {
    '^@taladelivery/([^/]+)$': '<rootDir>/libs/$1/src',
    '^@taladelivery/([^/]+)/(.*)$': '<rootDir>/libs/$1/src/$2',
  },
  testTimeout: 30000,
  testPathIgnorePatterns: ['/node_modules/', '/dist/'],
};