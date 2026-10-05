import { validate } from 'class-validator';
import { StoreCategoryDto } from './store-category.dto';
import { CATEGORY_ICONS } from './category-icons';

describe('Flutter category icon keys', () => {
  it('accepts every supported Flutter icon', async () => {
    for (const { key } of CATEGORY_ICONS) {
      expect(await validate(Object.assign(new StoreCategoryDto(), { name: 'Test', icon: key }))).toEqual([]);
    }
  });
  it('rejects unknown icon keys', async () => {
    const errors = await validate(Object.assign(new StoreCategoryDto(), { name: 'Test', icon: 'arbitrary_font_codepoint' }));
    expect(errors.some((error) => error.property === 'icon')).toBe(true);
  });
});
