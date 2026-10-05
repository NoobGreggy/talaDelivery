import { ValidatorConstraint, ValidatorConstraintInterface } from 'class-validator';

export const MAX_PRODUCT_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_BASE64_LENGTH = Math.ceil(MAX_PRODUCT_IMAGE_BYTES / 3) * 4;

export function validProductImage(value: unknown): boolean {
  if (value === '' || value == null) return true;
  if (typeof value !== 'string') return false;
  // Keep existing hosted photos compatible with Base64 uploads.
  if (!value.startsWith('data:')) return value.length <= 2000 && /^(https?:\/\/|\/[^/])\S+$/i.test(value);
  const match = /^data:image\/(png|jpeg|gif|webp);base64,([A-Za-z0-9+/]+={0,2})$/.exec(value);
  if (!match || match[2].length > MAX_BASE64_LENGTH || match[2].length % 4 !== 0) return false;
  const bytes = Buffer.from(match[2], 'base64');
  if (bytes.length === 0 || bytes.length > MAX_PRODUCT_IMAGE_BYTES || bytes.toString('base64') !== match[2]) return false;
  switch (match[1]) {
    case 'png': return bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
    case 'jpeg': return bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
    case 'gif': return ['GIF87a', 'GIF89a'].includes(bytes.subarray(0, 6).toString('ascii'));
    case 'webp': return bytes.subarray(0, 4).toString('ascii') === 'RIFF' && bytes.subarray(8, 12).toString('ascii') === 'WEBP';
    default: return false;
  }
}

@ValidatorConstraint({ name: 'productImage', async: false })
export class ProductImageValidator implements ValidatorConstraintInterface {
  validate(value: unknown): boolean { return validProductImage(value); }
  defaultMessage(): string { return 'Image must be a PNG, JPEG, GIF or WebP Base64 image up to 5 MB, or a valid image URL.'; }
}
