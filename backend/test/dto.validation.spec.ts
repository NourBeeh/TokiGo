// The DTO decorators need the reflect-metadata polyfill (the Nest app
// loads it in main.ts; a bare Jest process has to load it itself).
import 'reflect-metadata';
import { validate } from 'class-validator';
import { FlightSearchDto } from '../src/common/dto/flight.search.dto';

describe('DTO Validation', () => {
  it('should fail when required fields missing', async () => {
    const dto = new FlightSearchDto();
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });
});
