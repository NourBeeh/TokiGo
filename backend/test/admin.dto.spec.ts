import { validate } from 'class-validator';
import { CreateCardDto, UpdateCardDto } from '../src/common/dto/admin.dto';

describe('Admin destination mood validation', () => {
  it('accepts only authored moods for a new destination', async () => {
    const dto = Object.assign(new CreateCardDto(), {
      sectionId: 'section-1',
      cardType: 'destination',
      content: {
        title: 'Dubai',
        metadata: { moods: ['shopping', 'city'] },
      },
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it('rejects missing, unknown, duplicate, and non-array moods on destinations', async () => {
    const invalidContents = [
      { title: 'Cairo' },
      { title: 'Cairo', metadata: { moods: ['museum'] } },
      { title: 'Cairo', metadata: { moods: ['city', 'city'] } },
      { title: 'Cairo', metadata: { moods: 'city' } },
    ];

    for (const content of invalidContents) {
      const dto = Object.assign(new CreateCardDto(), {
        sectionId: 'section-1',
        cardType: 'destination',
        content,
      });
      expect(await validate(dto)).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ property: 'content' }),
        ]),
      );
    }
  });

  it('validates mood values in partial content updates', async () => {
    const dto = Object.assign(new UpdateCardDto(), {
      content: { metadata: { moods: ['beach', 'shopping mall'] } },
    });

    await expect(validate(dto)).resolves.toEqual(
      expect.arrayContaining([
        expect.objectContaining({ property: 'content' }),
      ]),
    );
  });

  it('allows unrelated cards without destination moods', async () => {
    const dto = Object.assign(new CreateCardDto(), {
      sectionId: 'section-1',
      cardType: 'hotel',
      content: { title: 'Palm Beach Resort' },
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
  });
});
