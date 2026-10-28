import { Repository } from 'typeorm';
import { HomeCard } from '../src/database/entities/home_card.entity';
import { HomeSection } from '../src/database/entities/home_section.entity';
import { HomeService } from '../src/modules/home/home.service';

describe('HomeService wire schema', () => {
  it('maps persisted entities to the Flutter Home repository contract', async () => {
    const visibleSection = {
      id: 'section-1',
      title: 'Recommended',
      subtitle: 'For you',
      layout: 'horizontal',
      order: 1,
      isVisible: true,
      expiresAt: new Date('2099-09-01T00:00:00.000Z'),
    } as HomeSection;
    const hiddenSection = {
      id: 'section-2',
      title: 'Hidden',
      layout: 'grid',
      order: 2,
      isVisible: false,
    } as HomeSection;
    const visibleCard = {
      id: 'card-1',
      sectionId: 'section-1',
      cardType: 'hotel',
      order: 1,
      isVisible: true,
      content: {
        title: 'Grand Palm',
        price: 250,
        rating: 4.8,
        reviewCount: 120,
        actionLabel: 'View hotel',
        rawPrice: 300,
        metadata: { city: 'Cairo' },
      },
    } as HomeCard;
    const destinationCard = {
      id: 'card-destination',
      sectionId: 'section-1',
      cardType: 'destination',
      order: 2,
      isVisible: true,
      content: {
        title: 'Dubai',
        metadata: { country: 'United Arab Emirates', moods: ['shopping', 'city'] },
      },
    } as HomeCard;
    const hiddenCard = {
      id: 'card-2',
      sectionId: 'section-1',
      cardType: 'hotel',
      order: 2,
      isVisible: false,
      content: { title: 'Hidden hotel' },
    } as HomeCard;
    const foreignCard = {
      id: 'card-3',
      sectionId: 'section-2',
      cardType: 'hotel',
      order: 1,
      isVisible: true,
      content: { title: 'Foreign hotel' },
    } as HomeCard;

    const sectionRepo = {
      find: jest.fn().mockResolvedValue([visibleSection]),
    } as unknown as Repository<HomeSection>;
    const cardRepo = {
      find: jest.fn().mockResolvedValue([visibleCard, destinationCard]),
    } as unknown as Repository<HomeCard>;
    const service = new HomeService(sectionRepo, cardRepo);

    await expect(service.getSections()).resolves.toEqual([
      expect.objectContaining({
        id: 'section-1',
        title: 'Recommended',
        layout: 'horizontal',
        visibility: true,
        expiration: visibleSection.expiresAt,
        cards: [
          expect.objectContaining({
            id: 'card-1',
            type: 'hotel',
            title: 'Grand Palm',
            reviewCount: 120,
            action: 'View hotel',
            actionLabel: 'View hotel',
            rawPrice: 300,
            metadata: { city: 'Cairo' },
            visibility: true,
          }),
          expect.objectContaining({
            id: 'card-destination',
            type: 'destination',
            title: 'Dubai',
            metadata: {
              country: 'United Arab Emirates',
              moods: ['shopping', 'city'],
            },
          }),
        ],
      }),
    ]);

    expect(sectionRepo.find).toHaveBeenCalledWith({
      where: { isVisible: true },
      order: { order: 'ASC' },
    });
    expect(cardRepo.find).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ isVisible: true }),
      order: { order: 'ASC' },
    }));

    void hiddenSection;
    void hiddenCard;
    void foreignCard;
  });
});
