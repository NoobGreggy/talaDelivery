import { MAX_PRODUCT_IMAGE_BYTES, validProductImage } from './product-image.validator';
const pngHeader = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const image = (size: number) => {
  const bytes = Buffer.alloc(size); pngHeader.copy(bytes);
  return `data:image/png;base64,${bytes.toString('base64')}`;
};
describe('Product image uploads', () => {
  it('accepts a Base64 upload larger than the old 2000-character limit', () => expect(validProductImage(image(4096))).toBe(true));
  it('accepts a file at exactly 5 MiB', () => expect(validProductImage(image(MAX_PRODUCT_IMAGE_BYTES))).toBe(true));
  it('rejects a file above 5 MiB', () => expect(validProductImage(image(MAX_PRODUCT_IMAGE_BYTES + 1))).toBe(false));
  it('allows removal and existing hosted image URLs', () => {
    expect(validProductImage('')).toBe(true);
    expect(validProductImage('https://example.com/product.jpg')).toBe(true);
  });
  it('rejects malformed Base64, SVG, non-images and MIME/signature mismatches', () => {
    for (const value of ['data:image/png;base64,!!!!', 'data:image/svg+xml;base64,PHN2Zz4=', 'javascript:alert(1)',
      'data:image/jpeg;base64,aGVsbG8=', 42]) expect(validProductImage(value)).toBe(false);
  });
});
