import { Injectable } from '@nestjs/common';
import { CarProvider } from '../../../common/providers/car.provider';
import { ProviderResult } from '../../../common/providers/provider.result';

/**
 * Rich deterministic car catalogue behind the shared CarProvider contract
 * (spec point 30): the car vendor is intentionally NOT chosen yet — this
 * adapter keeps the same interface a real vendor adapter will implement, so
 * swapping providers requires zero domain/UI changes.
 *
 * Prices are quoted per day in USD; the search service attaches the EGP
 * display price via MarketContext like every other vertical.
 */

const CITY_NAMES: Record<string, { city: string; country: string }> = {
  cairo: { city: 'Cairo', country: 'Egypt' },
  'القاهرة': { city: 'Cairo', country: 'Egypt' },
  dubai: { city: 'Dubai', country: 'UAE' },
  'دبي': { city: 'Dubai', country: 'UAE' },
  riyadh: { city: 'Riyadh', country: 'Saudi Arabia' },
  'الرياض': { city: 'Riyadh', country: 'Saudi Arabia' },
  jeddah: { city: 'Jeddah', country: 'Saudi Arabia' },
  'جدة': { city: 'Jeddah', country: 'Saudi Arabia' },
};

const CATALOGUE = [
  {
    name: 'Toyota Corolla',
    carType: 'Economy',
    transmission: 'Automatic',
    seats: 5,
    doors: 4,
    largeBags: 2,
    dailyRate: 32,
    features: ['Air conditioning', 'Bluetooth', 'USB charging', 'Backup camera'],
    imageUrl: 'https://images.unsplash.com/photo-1621007947382-bb3c3994e3fb?w=800&q=80',
    supplier: 'Avis',
    cancellationPolicy: 'Free cancellation up to 24h before pickup',
    mileagePolicy: 'Unlimited mileage',
  },
  {
    name: 'Hyundai Elantra',
    carType: 'Compact',
    transmission: 'Automatic',
    seats: 5,
    doors: 4,
    largeBags: 2,
    dailyRate: 27,
    features: ['Air conditioning', 'Apple CarPlay', 'Cruise control'],
    imageUrl: 'https://images.unsplash.com/photo-1590362891991-f776e747a588?w=800&q=80',
    supplier: 'Europcar',
    cancellationPolicy: 'Free cancellation up to 48h before pickup',
    mileagePolicy: '300 km/day included',
  },
  {
    name: 'Kia Sportage',
    carType: 'SUV',
    transmission: 'Automatic',
    seats: 5,
    doors: 5,
    largeBags: 3,
    dailyRate: 55,
    features: ['All-wheel drive', 'Roof rack', 'Apple CarPlay', 'Heated seats'],
    imageUrl: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=800&q=80',
    supplier: 'Hertz',
    cancellationPolicy: 'Free cancellation up to 24h before pickup',
    mileagePolicy: 'Unlimited mileage',
  },
  {
    name: 'Mercedes-Benz C-Class',
    carType: 'Luxury',
    transmission: 'Automatic',
    seats: 5,
    doors: 4,
    largeBags: 3,
    dailyRate: 95,
    features: ['Leather seats', 'Premium sound', 'Navigation', 'Ambient lighting'],
    imageUrl: 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d2?w=800&q=80',
    supplier: 'Sixt',
    cancellationPolicy: 'Free cancellation up to 48h before pickup',
    mileagePolicy: '200 km/day included',
  },
  {
    name: 'Toyota Hiace Van',
    carType: 'Van',
    transmission: 'Manual',
    seats: 12,
    doors: 5,
    largeBags: 6,
    dailyRate: 78,
    features: ['Extra luggage space', 'Air conditioning', 'Driver option available'],
    imageUrl: 'https://images.unsplash.com/photo-1600661653561-629509216228?w=800&q=80',
    supplier: 'Local Supplier',
    cancellationPolicy: 'Free cancellation up to 72h before pickup',
    mileagePolicy: 'Unlimited mileage',
  },
  {
    name: 'Nissan Sunny',
    carType: 'Economy',
    transmission: 'Manual',
    seats: 5,
    doors: 4,
    largeBags: 1,
    dailyRate: 21,
    features: ['Air conditioning', 'Bluetooth'],
    imageUrl: 'https://images.unsplash.com/photo-1549927421-a8788b4577e2?w=800&q=80',
    supplier: 'Avis',
    cancellationPolicy: 'Free cancellation up to 24h before pickup',
    mileagePolicy: 'Unlimited mileage',
  },
];

@Injectable()
export class MockCarProvider implements CarProvider {
  providerId = 'mock-car';
  providerName = 'TokiGo Car Catalogue';

  async searchCars(params: {
    pickupLocation: string;
    pickupTime: Date;
    dropoffTime: Date;
  }): Promise<ProviderResult<any[]>> {
    const locationKey = (params.pickupLocation || '').trim().toLowerCase();
    const location = CITY_NAMES[locationKey] ?? {
      city: params.pickupLocation || 'Cairo',
      country: 'Egypt',
    };

    const pickup = params.pickupTime instanceof Date ? params.pickupTime : new Date(params.pickupTime);
    const dropoff = params.dropoffTime instanceof Date ? params.dropoffTime : new Date(params.dropoffTime);
    const days = Math.max(
      1,
      Math.ceil((dropoff.getTime() - pickup.getTime()) / (24 * 60 * 60 * 1000)),
    );

    const data = CATALOGUE.map((car, index) => {
      const total = car.dailyRate * days;
      return {
        id: `car-${location.city.toLowerCase()}-${index}`,
        type: 'car',
        providerId: this.providerId,
        providerName: this.providerName,
        title: car.name,
        subtitle: `${car.carType} · ${car.supplier}`,
        description: `${car.name} ${car.carType.toLowerCase()} with ${car.features.join(', ').toLowerCase()}.`,
        imageUrl: car.imageUrl,
        price: total,
        currency: 'USD',
        pickupLocation: `${location.city} — ${location.city} Downtown`,
        dropoffLocation: `${location.city} — ${location.city} Downtown`,
        pickupTime: pickup.toISOString(),
        dropoffTime: dropoff.toISOString(),
        carType: car.carType,
        transmission: car.transmission,
        seats: car.seats,
        supplier: car.supplier,
        originalPrice: Math.round(total * 1.15),
        metadata: {
          dailyRate: car.dailyRate,
          rentalDays: days,
          features: car.features,
          cancellationPolicy: car.cancellationPolicy,
          mileagePolicy: car.mileagePolicy,
          largeBags: car.largeBags,
          doors: car.doors,
          retrievedAt: new Date().toISOString(),
          expiresAt: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
        },
      };
    });

    return {
      success: true,
      providerId: this.providerId,
      providerName: this.providerName,
      data,
      timestamp: new Date(),
      metadata: { rentalDays: days, location: location.city },
    };
  }
}
