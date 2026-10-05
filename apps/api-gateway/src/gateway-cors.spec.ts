import { gatewayCorsOrigins } from './gateway-cors';

describe('gateway browser origins', () => {
  it('allows known local admin and merchant origins by default', () => {
    expect(gatewayCorsOrigins()).toEqual(expect.arrayContaining([
      'http://localhost:4200', 'http://localhost:4300',
    ]));
    expect(gatewayCorsOrigins()).not.toContain('*');
  });
  it('uses an explicit deployment allowlist without adding local origins', () => {
    expect(gatewayCorsOrigins(' https://admin.example.com,https://merchant.example.com,https://admin.example.com '))
      .toEqual(['https://admin.example.com', 'https://merchant.example.com']);
  });
  it.each(['*', 'https://admin.example.com/path', 'https://admin.example.com/', 'ftp://example.com'])
    ('rejects invalid or wildcard origins: %s', value => {
      expect(() => gatewayCorsOrigins(value)).toThrow();
    });
});
